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

  TODO: This needs some love:
   - Make more explicit a FragmentGraph that is being built and a finalized
     FragmentGraph
   - Update RDF.Data to 0.9 interface of rdf-ex
  """

  @enforce_keys [:base_subject]
  defstruct base_subject: nil, statements: %{}, fragment_statements: %{}

  alias RDF.FragmentGraph.CSexp
  alias RDF.FragmentGraph.FragmentReference

  alias RDF.Data
  alias RDF.Description
  alias RDF.IRI
  alias RDF.Literal
  alias RDF.Statement

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
  # Specialized coercers that do not allow blank nodes and return
  # FragmentReferences

  @spec coerce_iri(IRI.t(), coerce_options()) :: IRI.t() | FragmentReference.t() | atom
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
    parsed = IRI.parse(base_subject)

    IRI.new!(%{parsed | fragment: identifier})
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
  Returns a `RDF.Description` of the given subject with statements in `RDF.FragmentGraph`.
  """
  @spec description(t, subject) :: Description.t()
  def description(%__MODULE__{} = fg, subject) do
    case(coerce_iri(subject, base_subject: fg.base_subject)) do
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
  Returns true if the `RDF.FragmentGraph` contains a statement about given subject.
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
  Returns a set of all objects in `RDF.FragmentGraph`
  """
  @spec objects(t) :: [IRI.t() | Literal.t()]
  def objects(%__MODULE__{} = fg) do
    fg.fragment_statements
    |> Map.values()
    |> Enum.reduce(fg.statements, &Map.merge(&1, &2))
    |> Map.values()
    |> Enum.reduce(MapSet.new(), &MapSet.union(&1, &2))
    |> Enum.map(&expand_term(&1, base_subject: fg.base_subject))
  end

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

  # Helper to create a FragmentGraph with a dummy base subject (useful when creating a content-addressed Frgment Graph).
  @spec new() :: t
  def new, do: new("urn:fragment-graph-to-be-finalized")

  @doc """
  Returns a fragment reference to `id`.

  This is a shortcut to `RDF.FragmentGraph.FragmentReference.new(id)`.
  """
  def fragment_reference(id), do: FragmentReference.new(id)

  defp add_to_statements(statements, coercible_predicate, coercible_object,
         base_subject: base_subject
       ) do
    with predicate <- coerce_predicate(coercible_predicate, base_subject: base_subject),
         object <- coerce_object(coercible_object, base_subject: base_subject) do
      Map.update(statements, predicate, MapSet.new([object]), fn objects ->
        MapSet.put(objects, object)
      end)
    end
  end

  defp delete_from_objects(objects, object) do
    with new_objects <- MapSet.delete(objects, object) do
      if Enum.empty?(new_objects), do: :pop, else: {objects, new_objects}
    end
  end

  defp delete_from_statements(
         statements,
         coercible_predicate,
         coercible_object,
         base_subject: base_subject
       ) do
    with predicate <- coerce_predicate(coercible_predicate, base_subject: base_subject),
         object <- coerce_object(coercible_object, base_subject: base_subject) do
      Map.get_and_update(statements, predicate, fn value ->
        case value do
          nil ->
            :pop

          objects ->
            delete_from_objects(objects, object)
        end
      end)
      |> elem(1)
    end
  end

  @doc """
  Add a statement consisting of a predicate and an object to the `RDF.FragmentGraph`.
  """
  @spec add(t, coercible_predicate, coercible_object) :: t
  def add(%__MODULE__{statements: statements} = fg, predicate, object) do
    with new_statements <-
           add_to_statements(statements, predicate, object, base_subject: fg.base_subject) do
      %{fg | statements: new_statements}
    end
  end

  @doc """
  Delete a statement consisting of a predicate and an object from the `RDF.FragmentGraph`.
  """
  @spec delete(t, coercible_predicate, coercible_object) :: t
  def delete(%__MODULE__{statements: statements} = fg, predicate, object) do
    with new_statements <-
           delete_from_statements(statements, predicate, object, base_subject: fg.base_subject) do
      %{fg | statements: new_statements}
    end
  end

  @doc """
  Add object to a predicate of a fragemnt of the `RDF.FragmentGraph`.
  """
  @spec add_fragment_statement(t, fragment_identifier, coercible_predicate, coercible_object) :: t
  def add_fragment_statement(
        %__MODULE__{fragment_statements: fragment_statements} = fg,
        fragment_identifier,
        predicate,
        object
      ) do
    with new_fragments <-
           Map.update(
             fragment_statements,
             fragment_identifier,
             add_to_statements(%{}, predicate, object, base_subject: fg.base_subject),
             fn statements ->
               add_to_statements(statements, predicate, object, base_subject: fg.base_subject)
             end
           ) do
      %{fg | fragment_statements: new_fragments}
    end
  end

  @doc """
  Delete a fragment statement from the `RDF.FragmentGraph`.
  """
  @spec delete_fragment_statement(t, fragment_identifier, coercible_predicate, coercible_object) ::
          t
  def delete_fragment_statement(
        %__MODULE__{fragment_statements: fragment_statements} = fg,
        fragment_identifier,
        predicate,
        object
      ) do
    case Map.update(
           fragment_statements,
           fragment_identifier,
           %{},
           &delete_from_statements(&1, predicate, object, base_subject: fg.base_subject)
         ) do
      %{} ->
        %{fg | fragment_statements: Map.delete(fragment_statements, fragment_identifier)}

      new_fragment_statements ->
        %{fg | fragment_statements: new_fragment_statements}
    end
  end

  @doc """
  Add statement to `RDF.FragmentGraph`.
  """
  @spec add(t, Statement.t() | [Statement.t()] | Data.t()) :: t
  def add(fg, statements)

  def add(fg, {predicate, object}), do: add(fg, predicate, object)

  def add(%__MODULE__{} = fg, {s, p, o}) do
    case coerce_iri(s, base_subject: fg.base_subject) do
      :base_subject ->
        add(fg, p, o)

      %FragmentReference{identifier: identifier} ->
        add_fragment_statement(fg, identifier, p, o)

      _ ->
        fg
    end
  end

  def add(fg, {_g, s, p, o}), do: add(fg, {s, p, o})
  def add(fg, statements) when is_list(statements), do: Enum.reduce(statements, fg, &add(&2, &1))
  def add(fg, data), do: add(fg, Data.statements(data))

  @doc """
  Delete statement(s) from `RDF.FragmentGraph`.
  """
  @spec delete(t, Statement.t() | [Statement.t()] | Data.t()) :: t
  def delete(fg, statements)

  def delete(fg, {s, p, o}) do
    case coerce_iri(s, base_subject: fg.base_subject) do
      :base_subject ->
        delete(fg, p, o)

      %FragmentReference{identifier: identifier} ->
        delete_fragment_statement(fg, identifier, p, o)

      _ ->
        fg
    end
  end

  def delete(fg, {_g, s, p, o}), do: delete(fg, {s, p, o})

  def delete(fg, statements) when is_list(statements) do
    Enum.reduce(statements, fg, &delete(&2, &1))
  end

  def delete(fg, data), do: delete(fg, Data.statements(data))

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
  Finalize the `RDF.FragmentGraph` by setting the base subject to the ERIS URN
  of the content.

  TODO: This binds the `RDF.FragmentGraph` implementation to `ERIS`. Maybe this
  can be separated in a nice way?
  """
  @spec finalize(t) :: t
  def finalize(%__MODULE__{} = fg) do
    with csexp <- CSexp.encode(fg),
         urn <- ERIS.encode_urn(csexp) do
      set_base_subject(fg, urn)
    end
  end

  #########################
  # Implement the `RDF.Data` protocol.
  #########################

  defimpl RDF.Data, for: RDF.FragmentGraph do
    @dialyzer {:nowarn_function, delete: 3}
    def delete(%RDF.FragmentGraph{} = fg, statements, _opts) do
      RDF.FragmentGraph.delete(fg, statements)
    end

    @dialyzer {:nowarn_function, describes?: 2}
    def describes?(%RDF.FragmentGraph{} = fg, %IRI{} = iri) do
      RDF.FragmentGraph.describes?(fg, iri)
    end

    @dialyzer {:nowarn_function, description: 2}
    def description(%RDF.FragmentGraph{} = fg, subject) do
      RDF.FragmentGraph.description(fg, subject)
    end

    @dialyzer {:nowarn_function, descriptions: 1}
    def descriptions(%RDF.FragmentGraph{} = fg) do
      fg
      |> RDF.Data.subjects()
      |> Enum.map(&description(fg, &1))
    end

    @dialyzer {:nowarn_function, equal?: 2}
    def equal?(data1, data2), do: data1 == data2

    @dialyzer {:nowarn_function, include?: 3}
    def include?(%RDF.FragmentGraph{} = fg, {s, p, o}, _opts) do
      case RDF.FragmentGraph.coerce_iri(s, fg.base_subject) do
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

    @dialyzer {:nowarn_function, merge: 3}
    def merge(%RDF.FragmentGraph{} = fg, data, _opts) do
      fg
      |> statements()
      |> RDF.Graph.new()
      |> RDF.Graph.add(RDF.Data.statements(data))
    end

    @dialyzer {:nowarn_function, objects: 1}
    def objects(%RDF.FragmentGraph{} = fg), do: RDF.FragmentGraph.objects(fg)

    @dialyzer {:nowarn_function, pop: 1}
    def pop(%RDF.FragmentGraph{} = fg) do
      case fg |> subjects() |> MapSet.to_list() do
        [] -> {nil, fg}
        [subject | _] -> Access.pop(fg, subject)
      end
    end

    @dialyzer {:nowarn_function, predicates: 1}
    def predicates(%RDF.FragmentGraph{} = fg), do: RDF.FragmentGraph.predicates(fg)

    @dialyzer {:nowarn_function, resources: 1}
    def resources(%RDF.FragmentGraph{} = fg) do
      [RDF.Data.subjects(fg), RDF.Data.objects(fg), RDF.Data.predicates(fg)]
      |> Enum.reduce(MapSet.new(), &MapSet.union(&1, &2))
    end

    @dialyzer {:nowarn_function, statement_count: 1}
    def statement_count(%RDF.FragmentGraph{} = fg) do
      fg
      |> RDF.Data.statements()
      |> Enum.count()
    end

    @dialyzer {:nowarn_function, statements: 1}
    def statements(%RDF.FragmentGraph{} = fg), do: RDF.FragmentGraph.statements(fg)

    @dialyzer {:nowarn_function, subject_count: 1}
    def subject_count(%RDF.FragmentGraph{} = fg) do
      fg
      |> RDF.Data.subjects()
      |> Enum.count()
    end

    @dialyzer {:nowarn_function, subjects: 1}
    def subjects(%RDF.FragmentGraph{} = fg), do: RDF.FragmentGraph.subjects(fg)

    @dialyzer {:nowarn_function, values: 1}
    def values(%RDF.FragmentGraph{} = fg) do
      fg
      |> RDF.Data.statements()
      |> RDF.Graph.new()
      |> RDF.Data.values()
    end

    @dialyzer {:nowarn_function, values: 2}
    def values(%RDF.FragmentGraph{} = fg, mapping) do
      fg
      |> RDF.Data.statements()
      |> RDF.Graph.new()
      |> RDF.Data.values(mapping)
    end
  end

  # Implement the Access Behaviour

  @behaviour Access

  @impl Access
  def fetch(%__MODULE__{} = fg, %IRI{} = key) do
    if key in subjects(fg) do
      {:ok, description(fg, key)}
    else
      :error
    end
  end

  def fetch(%__MODULE__{} = fg, key) when is_binary(key) do
    subject = expand_fragment_subject(key, fg.base_subject)

    Access.fetch(fg, subject)
  end

  def fetch(%__MODULE__{} = fg, :base_subject) do
    Access.fetch(fg, fg.base_subject)
  end

  @doc """
  Pops the description of the given subject.
  """
  @impl Access
  def pop(%__MODULE__{} = fg, %IRI{} = key) do
    if key in subjects(fg) do
      with description <- description(fg, key) do
        {description, delete(fg, description)}
      end
    else
      {nil, fg}
    end
  end

  def pop(%__MODULE__{} = fg, key) when is_binary(key) do
    iri = expand_fragment_subject(key, fg.base_subject)

    pop(fg, iri)
  end

  def pop(%__MODULE__{} = fg, :base_subject) do
    iri = fg.base_subject

    pop(fg, iri)
  end

  @impl Access
  def get_and_update(%__MODULE__{}, _key, _function) do
    # TODO
    raise "not implemented"
  end
end
