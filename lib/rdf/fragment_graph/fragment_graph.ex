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
  """

  alias RDF.FragmentGraph.FragmentReference
  alias RDF.{IRI, Literal, Statement}

  @type subject :: IRI.t()
  @type predicate :: IRI.t() | FragmentReference.t()
  @type object :: IRI.t() | Literal.t() | FragmentReference.t()

  @type coercible_subject :: IRI.coercible()
  @type coercible_predicate :: IRI.coercible()
  @type coericble_object :: IRI.coercible() | Literal.literal_value()

  @type fragment_identifier :: String.t()

  @type statements :: %{optional(predicate()) => MapSet.t(object)}
  @type fragment_statements :: %{optional(fragment_identifier()) => statements()}

  @type t :: %__MODULE__{
          base_subject: subject,
          statements: statements,
          fragment_statements: fragment_statements
        }

  @enforce_keys [:base_subject]
  defstruct base_subject: nil, statements: %{}, fragment_statements: %{}

  defmodule FragmentReference do
    @moduledoc """
    An reference inside a `RDF.FragmentGraph` to another fragment.
    """
    @type t :: %__MODULE__{
            identifier: String.t()
          }
    defstruct identifier: nil

    @doc """
    Returns a new `FragmentReference`
    """
    def new(identifier) do
      %__MODULE__{identifier: identifier}
    end
  end

  #########################
  # Specialized coercers that do not allow blank nodes and return
  # FragmentReferences

  @type coerce_options :: [base_subject: IRI.t()]

  @spec coerce_iri(IRI.t(), coerce_options()) ::
          IRI.t() | FragmentReference.t() | atom
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
    IRI.new!(iri)
    |> coerce_iri(base_subject: base_subject)
  end

  @doc false
  @spec coerce_predicate(coercible_predicate(), coerce_options()) :: predicate
  defp coerce_predicate(%IRI{} = iri, opts) do
    case coerce_iri(iri, opts) do
      :base_subject -> FragmentReference.new("")
      p -> p
    end
  end

  defp coerce_predicate(iri, opts) when is_atom(iri) or is_binary(iri),
    do: coerce_predicate(RDF.iri!(iri), opts)

  defp coerce_predicate(arg, _), do: raise(RDF.Triple.InvalidPredicateError, predicate: arg)

  @doc false
  @spec coerce_object(coericble_object(), coerce_options()) :: object
  defp coerce_object(%IRI{} = iri, opts) do
    case coerce_iri(iri, opts) do
      :base_subject -> FragmentReference.new("")
      o -> o
    end
  end

  defp coerce_object(iri, opts) when is_atom(iri),
    do: coerce_object(RDF.iri!(iri), opts)

  defp coerce_object(arg, _), do: Literal.new(arg)

  #########################
  # Expand terms and statements to usual `RDF` term and statements (without
  # `FragmentReference`)

  defp expand_term(%IRI{} = iri, _opts), do: iri

  defp expand_term(%FragmentReference{identifier: identifier}, base_subject: base_subject) do
    parsed = IRI.parse(base_subject)
    IRI.new!(%{parsed | fragment: identifier})
  end

  defp expand_term(%Literal{} = literal, _opts), do: literal

  defp expand_statements(statements, subject, base_subject) do
    statements
    |> Enum.reduce([], fn {p, object_set}, sts ->
      expanded_p = expand_term(p, base_subject: base_subject)

      sts ++
        (object_set
         |> Enum.map(fn object ->
           {subject, expanded_p, expand_term(object, base_subject: base_subject)}
         end))
    end)
  end

  defp expand_fragment_subject(fragment_identifier, base_subject) do
    expand_term(FragmentReference.new(fragment_identifier), base_subject: base_subject)
  end

  @doc """
  Returns a `RDF.Description` of the given subject with statements in `RDF.FragmentGraph`.
  """
  def description(%__MODULE__{} = fg, subject) do
    case(coerce_iri(subject, base_subject: fg.base_subject)) do
      :base_subject ->
        RDF.Description.new(subject)
        |> RDF.Description.add(expand_statements(fg.statements, subject, fg.base_subject))

      %FragmentReference{identifier: identifier} ->
        with fragment_subject <-
               expand_fragment_subject(identifier, fg.base_subject) do
          RDF.Description.new(fragment_subject)
          |> RDF.Description.add(
            Map.get(fg.fragment_statements, identifier, %{})
            |> expand_statements(fragment_subject, fg.base_subject)
          )
        end

      %RDF.IRI{} = iri ->
        RDF.Description.new(iri)
    end
  end

  @doc """
  Returns a list of all statements in `RDF.FragmentGraph`.
  """
  def statements(%__MODULE__{} = fg) do
    with expanded_statements <-
           fg.statements |> expand_statements(fg.base_subject, fg.base_subject),
         expanded_fragment_statements <-
           fg.fragment_statements
           |> Enum.flat_map(fn {id, statements} ->
             statements
             |> expand_statements(
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
  def predicates(%__MODULE__{} = fg) do
    fg.fragment_statements
    |> Map.values()
    |> Enum.flat_map(&Map.keys(&1))
    |> Enum.concat(fg.statements |> Map.keys())
    |> MapSet.new()
  end

  @doc """
  Returns a set of all objects in `RDF.FragmentGraph`
  """
  def objects(%__MODULE__{} = fg) do
    fg.fragment_statements
    |> Map.values()
    |> Enum.reduce(fg.statements, &Map.merge(&1, &2))
    |> Map.values()
    |> Enum.reduce(MapSet.new(), &MapSet.union(&1, &2))
    |> Enum.map(&expand_term(&1, base_subject: fg.base_subject))
  end

  # Helper to get a subject from RDF.Data
  defp find_subject(data) do
    data
    |> RDF.Data.subjects()
    |> Enum.find(nil, fn %IRI{} = iri ->
      iri |> IRI.parse() |> Map.get(:fragment) |> is_nil()
    end)
  end

  @doc """
  Create a new RDF Fragment Graph.
  """
  @spec new(RDF.Data.t() | subject | IRI.coercible()) :: t
  def new(data_or_iri)
  def new(%IRI{} = iri), do: %__MODULE__{base_subject: iri}

  def new(data_or_iri) do
    if RDF.Data.impl_for(data_or_iri) do
      subject = find_subject(data_or_iri)
      add(new(subject), data_or_iri)
    else
      %__MODULE__{base_subject: IRI.new!(data_or_iri)}
    end
  end

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

  @doc """
  Add a statement consisting of a predicate and an object to the `RDF.FragmentGraph`.
  """
  @spec add(t, coercible_predicate(), coericble_object()) :: t
  def add(
        %__MODULE__{statements: statements} = fg,
        predicate,
        object
      ) do
    with new_statements <-
           add_to_statements(statements, predicate, object, base_subject: fg.base_subject) do
      %{fg | statements: new_statements}
    end
  end

  @doc """
  Add object to a predicate of a fragemnt of the `RDF.FragmentGraph`.
  """
  @spec add_fragment_statement(
          t,
          fragment_identifier(),
          coercible_predicate(),
          coericble_object()
        ) :: t
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
  Add statement to `RDF.FragmentGraph`.
  """
  @spec add(t, Statement.t() | [Statement.t()] | RDF.Data.t()) :: t
  def add(fg, statements)

  def add(fg, {predicate, object}),
    do: add(fg, predicate, object)

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

  def add(fg, statements) when is_list(statements) do
    Enum.reduce(statements, fg, fn statement, fg -> add(fg, statement) end)
  end

  def add(fg, data) do
    add(fg, RDF.Data.statements(data))
  end

  @doc """
  Set subject of `RDF.FragmentGraph`
  """
  @spec set_subject(t, IRI.t()) :: t
  def set_subject(%__MODULE__{} = fg, subject) do
    %{fg | base_subject: subject}
  end

  #########################
  # Implement the `RDF.Data` protocol.

  defimpl RDF.Data, for: RDF.FragmentGraph do
    def delete(%RDF.FragmentGraph{}, _) do
      # TODO
      raise "not implemented"
    end

    def describes?(%RDF.FragmentGraph{base_subject: base_subject} = fg, %IRI{} = iri) do
      case RDF.FragmentGraph.coerce_iri(iri, base_subject: base_subject) do
        :base_subject ->
          not Enum.empty?(fg.statements)

        %FragmentReference{identifier: identifier} ->
          not is_nil(fg.fragment_statements[identifier])

        _ ->
          false
      end
    end

    def description(%RDF.FragmentGraph{} = fg, subject),
      do: RDF.FragmentGraph.description(fg, subject)

    @doc """
    Returns all descriptions of the `RDF.FragmentGraph`.
    """
    def descriptions(%RDF.FragmentGraph{} = fg) do
      fg
      |> RDF.Data.subjects()
      |> Enum.map(&description(fg, &1))
    end

    def equal?(data1, data2) do
      data1 == data2
    end

    def include?(%RDF.FragmentGraph{} = fg, {s, p, o}) do
      case RDF.FragmentGraph.coerce_iri(s, fg.base_subject) do
        :base_subject ->
          Map.get(fg.statements, p, MapSet.new())
          |> MapSet.member?(o)

        %FragmentReference{identifier: identifier} ->
          Map.get(fg.fragment_statements, identifier, %{})
          |> Map.get(p, MapSet.new())
          |> MapSet.member?(o)

        _ ->
          false
      end
    end

    def merge(%RDF.FragmentGraph{} = fg, data) do
      fg
      |> RDF.FragmentGraph.add(data)
    end

    def objects(%RDF.FragmentGraph{} = fg), do: RDF.FragmentGraph.objects(fg)

    def pop(%RDF.FragmentGraph{}) do
      # TODO
      raise "not implemented"
    end

    def predicates(%RDF.FragmentGraph{}) do
      # TODO
      raise "not implemented"
    end

    def resources(%RDF.FragmentGraph{}) do
      # TODO
      raise "not implemented"
    end

    def statement_count(%RDF.FragmentGraph{} = fg) do
      fg
      |> RDF.Data.statements()
      |> Enum.count()
    end

    def statements(%RDF.FragmentGraph{} = fg), do: RDF.FragmentGraph.statements(fg)

    def subject_count(%RDF.FragmentGraph{} = fg) do
      fg
      |> RDF.Data.subjects()
      |> Enum.count()
    end

    def subjects(%RDF.FragmentGraph{} = fg), do: RDF.FragmentGraph.subjects(fg)

    def values(%RDF.FragmentGraph{}) do
      # TODO
      raise "not implemented"
    end

    def values(%RDF.FragmentGraph{}, _mapping) do
      # TODO
      raise "not implemented"
    end
  end

  # Implement the Access Behaviour

  @behaviour Access

  @impl Access
  def fetch(%__MODULE__{} = fg, %IRI{} = key) do
    if key in RDF.Data.subjects(fg) do
      {:ok, RDF.Data.description(fg, key)}
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

  @impl Access
  def pop(%__MODULE__{}, _key) do
    # TODO
    raise "not implemented"
  end

  @impl Access
  def get_and_update(%__MODULE__{}, _key, _function) do
    # TODO
    raise "not implemented"
  end
end
