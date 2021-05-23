# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.FragmentGraph do
  @moduledoc """
  A set of RDF triples about the same subject or fragments of the subject.

  Blank nodes are not permitted.

  An `RDF.FragmentGraph` defines a grouping of RDF triples about a certain
  subject that is suitable for content-addressing (see
  https://openengiadina.net/papers/content-addressable-rdf.html)

  It is similar to a `RDF.Description` but additionally allows statements with
  fragments of the base subject as subject (e.g. If ~I<http://example.com/> is
  the base subject of the `RDF.FragmentGraph` then statements with subject
  ~I<http://example.com/#a-fragment> are also permitted).

  `RDF.FragmentGraph` implements:
  - Elixir's `Access` behaviour
  - the `RDF.Data` protocol
  """

  @behaviour Access

  alias RDF.FragmentGraph.CSexp
  alias RDF.FragmentGraph.FragmentReference

  alias RDF.Data
  alias RDF.Description
  alias RDF.Graph
  alias RDF.IRI
  alias RDF.Literal
  alias RDF.Statement

  @enforce_keys [:base_subject]
  defstruct base_subject: nil, statements: %{}, fragment_statements: %{}

  @type subject :: IRI.t()
  @type predicate :: IRI.t() | FragmentReference.t()
  @type object :: IRI.t() | Literal.t() | FragmentReference.t()

  @type coercible_subject :: IRI.coercible()
  @type coercible_predicate :: IRI.coercible() | FragmentReference.t()
  @type coercible_object :: IRI.coercible() | Literal.t() | FragmentReference.t()

  @type coerce_options :: [base_subject: IRI.t()]

  @type fragment_identifier :: String.t()

  @type statements :: %{optional(predicate()) => MapSet.t(object)}
  @type fragment_statements :: %{optional(fragment_identifier()) => statements()}

  @type t :: %__MODULE__{
          base_subject: subject,
          statements: statements,
          fragment_statements: fragment_statements
        }

  defmodule FragmentReference do
    @moduledoc """
    An reference inside a `RDF.FragmentGraph` to another fragment.
    """

    defstruct identifier: nil

    @type t :: %__MODULE__{
            identifier: String.t()
          }

    @doc """
    Returns a new `FragmentReference`
    """
    @spec new(String.t()) :: t
    def new(identifier) do
      %__MODULE__{identifier: identifier}
    end
  end

  #########################
  # Specialized coercers that do not allow blank nodes and return FragmentReferences

  @spec coerce_iri(IRI.t(), coerce_options()) :: :base_subject | IRI.t() | FragmentReference.t()
  def coerce_iri(%IRI{} = iri, base_subject: base_subject) do
    uri = IRI.parse(iri)
    base_subject_uri = IRI.parse(base_subject)

    cond do
      base_subject == iri ->
        :base_subject

      %{uri | fragment: nil} == base_subject_uri ->
        FragmentReference.new(uri.fragment)

      true ->
        iri
    end
  end

  def coerce_iri(iri, base_subject: base_subject) do
    iri
    |> IRI.new!()
    |> coerce_iri(base_subject: base_subject)
  end

  @doc false
  @spec coerce_predicate(coercible_predicate(), coerce_options()) :: predicate
  def coerce_predicate(%IRI{} = iri, opts) do
    case coerce_iri(iri, opts) do
      :base_subject -> FragmentReference.new("")
      p -> p
    end
  end

  def coerce_predicate(%FragmentReference{} = f, _), do: f

  def coerce_predicate(iri, opts) when is_atom(iri) or is_binary(iri) do
    coerce_predicate(RDF.iri!(iri), opts)
  end

  def coerce_predicate(arg, _), do: raise(RDF.Triple.InvalidPredicateError, predicate: arg)

  @doc false
  @spec coerce_object(coercible_object(), coerce_options()) :: object
  def coerce_object(%IRI{} = iri, opts) do
    case coerce_iri(iri, opts) do
      :base_subject -> FragmentReference.new("")
      o -> o
    end
  end

  def coerce_object(%FragmentReference{} = f, _), do: f
  def coerce_object(iri, opts) when is_atom(iri), do: coerce_object(RDF.iri!(iri), opts)
  def coerce_object(arg, _), do: Literal.new(arg)

  #########################
  # Expand terms and statements to usual `RDF` term and statements (without
  # `FragmentReference`)

  @spec expand_term(IRI.t() | FragmentReference.t() | Literal.t(), coerce_options) ::
          IRI.t() | Literal.t()
  defp expand_term(%IRI{} = iri, _opts), do: iri

  defp expand_term(%FragmentReference{identifier: identifier}, base_subject: base_subject) do
    with parsed <- IRI.parse(base_subject), do: IRI.new!(%{parsed | fragment: identifier})
  end

  defp expand_term(%Literal{} = literal, _opts), do: literal

  @spec expand_statements(statements, subject, subject) :: [Statement.t()]
  defp expand_statements(statements, subject, base_subject) do
    Enum.reduce(statements, [], fn {p, object_set}, sts ->
      expanded_p = expand_term(p, base_subject: base_subject)

      sts ++
        Enum.map(object_set, fn object ->
          {subject, expanded_p, expand_term(object, base_subject: base_subject)}
        end)
    end)
  end

  @spec expand_fragment_subject(String.t(), subject) :: IRI.t() | Literal.t()
  defp expand_fragment_subject(fragment_identifier, base_subject) do
    expand_term(FragmentReference.new(fragment_identifier), base_subject: base_subject)
  end

  @doc """
  Create a new RDF Fragment Graph.
  """
  @spec new(IRI.coercible() | Data.t()) :: t
  def new(data_or_iri)
  def new(%IRI{} = iri), do: %__MODULE__{base_subject: iri}

  def new(data_or_iri) do
    if Data.impl_for(data_or_iri) do
      subject = find_subject(data_or_iri)
      add(new(subject), data_or_iri)
    else
      %__MODULE__{base_subject: IRI.new!(data_or_iri)}
    end
  end

  # Helper to create a FragmentGraph with a dummy base subject (useful when
  # creating a content-addressed Fragment Graph).
  @spec new() :: t
  def new, do: new("urn:fragment-graph-to-be-finalized")

  # Helper to get a subject from RDF.Data
  @spec find_subject(IRI.coercible() | Data.t()) :: subject | nil
  defp find_subject(data) do
    data
    |> Data.subjects()
    |> Enum.find(nil, fn %IRI{} = iri ->
      iri |> IRI.parse() |> Map.get(:fragment) |> is_nil()
    end)
  end

  @doc """
  Returns a fragment reference to `id`.

  This is a shortcut to `RDF.FragmentGraph.FragmentReference.new(id)`.
  """
  def fragment_reference(id), do: FragmentReference.new(id)

  @doc """
  Add statement to `RDF.FragmentGraph`.
  """
  @spec add(
          t,
          {coercible_predicate, coercible_object} | Statement.t() | [Statement.t()] | Data.t()
        ) :: t
  def add(fg, statements)

  def add(%__MODULE__{statements: statements} = fg, {predicate, object}) do
    with new_statements <-
           add_to_statements(statements, {predicate, object}, base_subject: fg.base_subject) do
      %{fg | statements: new_statements}
    end
  end

  def add(%__MODULE__{} = fg, {s, p, o}) do
    case coerce_iri(s, base_subject: fg.base_subject) do
      :base_subject ->
        add(fg, {p, o})

      %FragmentReference{identifier: identifier} ->
        add_fragment_statement(fg, identifier, {p, o})

      _ ->
        fg
    end
  end

  def add(fg, {_g, s, p, o}), do: add(fg, {s, p, o})
  def add(fg, statements) when is_list(statements), do: Enum.reduce(statements, fg, &add(&2, &1))
  def add(fg, data), do: add(fg, Data.statements(data))

  @doc """
  Add object to a predicate of a fragemnt of the `RDF.FragmentGraph`.
  """
  @spec add_fragment_statement(
          t,
          fragment_identifier,
          {coercible_predicate, coercible_object}
        ) :: t
  def add_fragment_statement(
        %__MODULE__{fragment_statements: fragment_statements} = fg,
        fragment_identifier,
        {predicate, object}
      ) do
    with new_fragments <-
           Map.update(
             fragment_statements,
             fragment_identifier,
             add_to_statements(%{}, {predicate, object}, base_subject: fg.base_subject),
             fn statements ->
               add_to_statements(statements, {predicate, object}, base_subject: fg.base_subject)
             end
           ) do
      %{fg | fragment_statements: new_fragments}
    end
  end

  defp add_to_statements(
         statements,
         {coercible_predicate, coercible_object},
         base_subject: base_subject
       ) do
    with predicate <- coerce_predicate(coercible_predicate, base_subject: base_subject),
         object <- coerce_object(coercible_object, base_subject: base_subject) do
      Map.update(statements, predicate, MapSet.new([object]), fn objects ->
        MapSet.put(objects, object)
      end)
    end
  end

  @doc """
  Delete statement(s) from `RDF.FragmentGraph`.
  """
  @spec delete(
          t,
          {coercible_predicate, coercible_object} | Statement.t() | [Statement.t()] | Data.t(),
          keyword
        ) :: t
  def delete(fg, statements, opts \\ [])

  def delete(%__MODULE__{statements: statements} = fg, {predicate, object}, _opts) do
    with new_statements <-
           delete_from_statements(statements, {predicate, object}, base_subject: fg.base_subject) do
      %{fg | statements: new_statements}
    end
  end

  def delete(fg, {s, p, o}, opts) do
    case coerce_iri(s, base_subject: fg.base_subject) do
      :base_subject ->
        delete(fg, {p, o}, opts)

      %FragmentReference{identifier: identifier} ->
        delete_fragment_statement(fg, identifier, {p, o})

      _ ->
        fg
    end
  end

  def delete(fg, {_g, s, p, o}, opts), do: delete(fg, {s, p, o}, opts)

  def delete(fg, statements, opts) when is_list(statements) do
    Enum.reduce(statements, fg, &delete(&2, &1, opts))
  end

  def delete(fg, data, opts), do: delete(fg, Data.statements(data), opts)

  @doc """
  Delete a fragment statement from the `RDF.FragmentGraph`.
  """
  @spec delete_fragment_statement(
          t,
          fragment_identifier,
          {coercible_predicate, coercible_object}
        ) :: t
  def delete_fragment_statement(
        %__MODULE__{fragment_statements: fragment_statements} = fg,
        fragment_identifier,
        {predicate, object}
      ) do
    with new_fragment_statements <-
           Map.update(
             fragment_statements,
             fragment_identifier,
             %{},
             &delete_from_statements(&1, {predicate, object}, base_subject: fg.base_subject)
           ) do
      if Enum.empty?(new_fragment_statements[fragment_identifier]) do
        %{fg | fragment_statements: Map.delete(fragment_statements, fragment_identifier)}
      else
        %{fg | fragment_statements: new_fragment_statements}
      end
    end
  end

  defp delete_from_statements(
         statements,
         {coercible_predicate, coercible_object},
         base_subject: base_subject
       ) do
    with predicate <- coerce_predicate(coercible_predicate, base_subject: base_subject),
         object <- coerce_object(coercible_object, base_subject: base_subject) do
      Map.get_and_update(statements, predicate, fn value ->
        case value do
          nil -> :pop
          objects -> delete_from_objects(objects, object)
        end
      end)
      |> elem(1)
    end
  end

  defp delete_from_objects(objects, object) do
    with new_objects <- MapSet.delete(objects, object) do
      if Enum.empty?(new_objects), do: :pop, else: {objects, new_objects}
    end
  end

  @spec merge(t, Statement.t(), keyword) :: Graph.t()
  def merge(%__MODULE__{} = fg, data, opts \\ []) do
    fg
    |> statements()
    |> Graph.new()
    |> Graph.add(Data.statements(data), opts)
  end

  @spec pop(t) :: {t | nil, t}
  def pop(%__MODULE__{} = fg) do
    case fg |> subjects() |> MapSet.to_list() do
      [] -> {nil, fg}
      [subject | _] -> Access.pop(fg, subject)
    end
  end

  @spec include?(t, Statement.t(), keyword) :: bool
  def include?(%__MODULE__{} = fg, {s, p, o}, _opts) do
    case coerce_iri(s, base_subject: fg.base_subject) do
      :base_subject ->
        fg.statements
        |> Map.get(p, MapSet.new())
        |> MapSet.member?(o)

      %FragmentReference{identifier: identifier} ->
        fg.fragment_statements
        |> Map.get(identifier, %{})
        |> Map.get(p, MapSet.new())
        |> MapSet.member?(o)

      _ ->
        false
    end
  end

  @doc """
  Checks if the `RDF.FragmentGraph` contains a statement about given subject.
  """
  @spec describes?(t, IRI.t()) :: bool
  def describes?(%__MODULE__{base_subject: base_subject} = fg, %IRI{} = iri) do
    case coerce_iri(iri, base_subject: base_subject) do
      :base_subject ->
        not Enum.empty?(fg.statements)

      %FragmentReference{identifier: identifier} ->
        not is_nil(fg.fragment_statements[identifier])

      _ ->
        false
    end
  end

  @doc """
  Returns a `RDF.Description` of the given subject with statements in `RDF.FragmentGraph`.
  """
  @spec description(t, subject) :: Description.t()
  def description(%__MODULE__{} = fg, subject) do
    case coerce_iri(subject, base_subject: fg.base_subject) do
      :base_subject ->
        subject
        |> Description.new()
        |> Description.add(expand_statements(fg.statements, subject, fg.base_subject))

      %FragmentReference{identifier: identifier} ->
        with fragment_subject <- expand_fragment_subject(identifier, fg.base_subject) do
          Description.new(fragment_subject)
          |> Description.add(
            fg.fragment_statements
            |> Map.get(identifier, %{})
            |> expand_statements(fragment_subject, fg.base_subject)
          )
        end

      %IRI{} = iri ->
        Description.new(iri)
    end
  end

  @spec descriptions(t) :: [Description.t()]
  def descriptions(%__MODULE__{} = fg) do
    fg
    |> Data.subjects()
    |> Enum.map(&description(fg, &1))
  end

  @doc """
  Return `RDF.Graph` for given `RDF.FragmentGraph`.
  """
  @spec graph(t) :: Graph.t()
  def graph(%__MODULE__{} = fg) do
    fg
    |> statements()
    |> RDF.Graph.new()
  end

  @doc """
  Returns a list of all statements in `RDF.FragmentGraph`.
  """
  @spec statements(t) :: [Statement.t()]
  def statements(%__MODULE__{} = fg) do
    with expanded_statements <-
           expand_statements(fg.statements, fg.base_subject, fg.base_subject),
         expanded_fragment_statements <-
           Enum.flat_map(fg.fragment_statements, fn {id, statements} ->
             expand_statements(
               statements,
               expand_fragment_subject(id, fg.base_subject),
               fg.base_subject
             )
           end) do
      expanded_statements ++ expanded_fragment_statements
    end
  end

  @doc """
  Returns a set of all subjects in `RDF.FragmentGraph`.
  """
  @spec subjects(t) :: MapSet.t(subject)
  def subjects(%__MODULE__{} = fg) do
    (if(Enum.empty?(fg.statements), do: [], else: [fg.base_subject]) ++
       (fg.fragment_statements
        |> Map.keys()
        |> Enum.map(&expand_fragment_subject(&1, fg.base_subject))))
    |> MapSet.new()
  end

  @doc """
  Retuns a set of all predicates in `RDF.FragmentGraph`
  """
  @spec predicates(t) :: MapSet.t(predicate)
  def predicates(%__MODULE__{} = fg) do
    fg.fragment_statements
    |> Map.values()
    |> Enum.flat_map(&Map.keys(&1))
    |> Enum.concat(Map.keys(fg.statements))
    |> MapSet.new()
  end

  @doc """
  Returns a set of all objects in `RDF.FragmentGraph`
  """
  @spec objects(t) :: MapSet.t(object)
  def objects(%__MODULE__{} = fg) do
    fg.fragment_statements
    |> Map.values()
    |> Enum.reduce(fg.statements, &Map.merge(&1, &2))
    |> Map.values()
    |> Enum.reduce(MapSet.new(), &MapSet.union(&1, &2))
    |> Enum.map(&expand_term(&1, base_subject: fg.base_subject))
    |> MapSet.new()
  end

  @spec resources(t) :: MapSet.t(subject | predicate | object)
  def resources(%__MODULE__{} = fg) do
    [Data.subjects(fg), Data.objects(fg), Data.predicates(fg)]
    |> Enum.reduce(MapSet.new(), &MapSet.union(&1, &2))
  end

  @spec subject_count(t) :: non_neg_integer
  def subject_count(%__MODULE__{} = fg) do
    fg
    |> Data.subjects()
    |> Enum.count()
  end

  @spec statement_count(t) :: non_neg_integer
  def statement_count(%__MODULE__{} = fg) do
    fg
    |> Data.statements()
    |> Enum.count()
  end

  @spec values(t, keyword) :: map
  def values(%__MODULE__{} = fg, opts \\ []) do
    fg
    |> Data.statements()
    |> Graph.new()
    |> Data.values(opts)
  end

  @spec map(t, ({atom, subject | predicate | object} -> any)) :: map
  def map(%__MODULE__{} = fg, fun) do
    fg
    |> graph()
    |> Graph.map(fun)
  end

  #########################
  # Content-addressing
  #########################

  @doc """
  Set the base subject of `RDF.FragmentGraph`.
  """
  @spec set_base_subject(t, IRI.coercible()) :: t
  def set_base_subject(%__MODULE__{} = fg, new_base_subject) do
    %{fg | base_subject: IRI.new!(new_base_subject)}
  end

  @doc """
  Finalize the `RDF.FragmentGraph` with a custom finalizer. The default finalizer
  sets the base subject to the ERIS URN of the content.
  """
  @spec finalize(t, (t -> String.t())) :: t
  def finalize(%__MODULE__{} = fg, finalizer \\ &eris_finalizer/1) do
    set_base_subject(fg, finalizer.(fg))
  end

  @spec eris_finalizer(t) :: String.t()
  def eris_finalizer(%__MODULE__{} = fg) do
    fg
    |> CSexp.encode()
    |> ERIS.encode_urn()
  end

  #########################
  # Implement the `RDF.Data` protocol
  #########################

  defimpl RDF.Data, for: RDF.FragmentGraph do
    alias RDF.FragmentGraph

    @dialyzer {:nowarn_function, merge: 3}
    defdelegate merge(fg, data, opts), to: FragmentGraph

    @dialyzer {:nowarn_function, delete: 3}
    defdelegate delete(fg, statements, opts), to: FragmentGraph

    @dialyzer {:nowarn_function, pop: 1}
    defdelegate pop(fg), to: FragmentGraph

    @dialyzer {:nowarn_function, include?: 3}
    defdelegate include?(fg, statement, opts), to: FragmentGraph

    @dialyzer {:nowarn_function, describes?: 2}
    defdelegate describes?(fg, iri), to: FragmentGraph

    @dialyzer {:nowarn_function, description: 2}
    defdelegate description(fg, subject), to: FragmentGraph

    @dialyzer {:nowarn_function, descriptions: 1}
    defdelegate descriptions(fg), to: FragmentGraph

    @dialyzer {:nowarn_function, statements: 1}
    defdelegate statements(fg), to: FragmentGraph

    @dialyzer {:nowarn_function, subjects: 1}
    defdelegate subjects(fg), to: FragmentGraph

    @dialyzer {:nowarn_function, predicates: 1}
    defdelegate predicates(fg), to: FragmentGraph

    @dialyzer {:nowarn_function, objects: 1}
    defdelegate objects(fg), to: FragmentGraph

    @dialyzer {:nowarn_function, resources: 1}
    defdelegate resources(fg), to: FragmentGraph

    @dialyzer {:nowarn_function, subject_count: 1}
    defdelegate subject_count(fg), to: FragmentGraph

    @dialyzer {:nowarn_function, statement_count: 1}
    defdelegate statement_count(fg), to: FragmentGraph

    @dialyzer {:nowarn_function, values: 2}
    defdelegate values(fg, opts), to: FragmentGraph

    @dialyzer {:nowarn_function, map: 2}
    defdelegate map(fg, fun), to: FragmentGraph

    @dialyzer {:nowarn_function, equal?: 2}
    def equal?(data1, data2), do: data1 == data2
  end

  #########################
  # Implement the `Access` behaviour
  #########################

  @doc """
  Fetches the description of the given subject.

  When the subject can not be found `:error` is returned.
  """
  @impl Access
  @spec fetch(t, Statement.coercible_subject()) :: {:ok, [Description.t()]} | :error
  def fetch(%__MODULE__{} = fg, %IRI{} = subject) do
    case subject in subjects(fg) do
      true -> {:ok, description(fg, subject)}
      false -> :error
    end
  end

  def fetch(%__MODULE__{} = fg, subject) when is_binary(subject) do
    with subject <- expand_fragment_subject(subject, fg.base_subject),
         do: Access.fetch(fg, subject)
  end

  def fetch(%__MODULE__{} = fg, :base_subject) do
    Access.fetch(fg, fg.base_subject)
  end

  @spec get(t, Statement.coercible_subject()) :: [Description.t()] | any
  def get(%__MODULE__{} = fg, subject, default \\ nil) do
    case fetch(fg, subject) do
      {:ok, value} -> value
      :error -> default
    end
  end

  @spec put(t, t | Graph.input(), keyword) :: t
  def put(fg, input, opts \\ [])

  def put(%__MODULE__{} = fg, %__MODULE__{} = input, opts) do
    fg
    |> graph()
    |> Graph.put(graph(input), opts)
    |> new()
  end

  def put(%__MODULE__{} = fg, input, opts) do
    fg
    |> graph()
    |> Graph.put(input, opts)
    |> new()
  end

  @spec put_properties(t, t | Graph.input(), keyword) :: t
  def put_properties(fg, input, opts \\ [])

  def put_properties(%__MODULE__{} = fg, %__MODULE__{} = input, opts) do
    fg
    |> graph()
    |> Graph.put_properties(graph(input), opts)
    |> new()
  end

  def put_properties(%__MODULE__{} = fg, input, opts) do
    fg
    |> graph()
    |> Graph.put_properties(input, opts)
    |> new()
  end

  @doc """
  Pops the description of the given subject.
  """
  @impl Access
  @spec pop(t, Statement.coercible_subject()) :: {t | nil, t}
  def pop(%__MODULE__{} = fg, %IRI{} = key) do
    case key in subjects(fg) do
      true ->
        with description <- description(fg, key),
             do: {description, delete(fg, description)}

      false ->
        {nil, fg}
    end
  end

  def pop(%__MODULE__{} = fg, key) when is_binary(key) do
    with iri <- expand_fragment_subject(key, fg.base_subject), do: pop(fg, iri)
  end

  def pop(%__MODULE__{} = fg, :base_subject) do
    with iri <- fg.base_subject, do: pop(fg, iri)
  end

  @impl Access
  @spec get_and_update(
          t,
          Statement.coercible_subject(),
          ([Description.t()] | nil -> {Description.t(), Description.t()} | :pop)
        ) :: {Description.t(), t}
  def get_and_update(%__MODULE__{} = fg, subject, fun) do
    case fun.(get(fg, subject)) do
      {old_description, new_description} ->
        {old_description, put(fg, {subject, new_description})}

      :pop ->
        pop(fg, subject)

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end
end
