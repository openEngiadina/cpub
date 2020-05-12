defmodule RDF.FragmentGraph do
  @moduledoc """
  A set of RDF triples about the same subject or fragments of the subject.

  Blank nodes are not permitted.

  An `RDF.FragmentGraph` defines a grouping of RDF triples about a certain
  subject that is suitable for content-addressing (see
  https://openengiadina.net/papers/content-addressable-rdf.html)

  It is similar to an `RDF.Description` but additionally allows statements with
  fragments of the base subject as subject (e.g. If ~I<http://example.com/> is
  the subject of the `RDF.FragmentGraph` then statements with subject
  ~I<http://example.com/#a-fragment> are also permitted).
  """

  alias RDF.{IRI, Literal, Statement}

  @type subject :: IRI.t()
  @type predicate :: IRI.t()
  @type object :: IRI.t() | Literal.t()

  @type coercible_subject :: IRI.coercible()
  @type coercible_predicate :: IRI.coercible()
  @type coericble_object :: IRI.coercible() | Literal.literal_value()

  @type fragment_identifier :: String.t()

  @type statements :: %{optional(predicate()) => MapSet.t(object)}
  @type fragment_statements :: %{optional(fragment_identifier()) => statements()}

  @type t :: %__MODULE__{
          subject: subject,
          statements: statements,
          fragment_statements: fragment_statements
        }

  @enforce_keys [:subject]
  defstruct subject: nil, statements: %{}, fragment_statements: %{}

  # Coercers that do not allow blank nodes

  @doc false
  @spec coerce_subject(coercible_subject()) :: subject
  def coerce_subject(%IRI{} = iri), do: iri
  def coerce_subject(iri) when is_atom(iri) or is_binary(iri), do: RDF.iri!(iri)
  def coerce_subject(arg), do: raise(RDF.Triple.InvalidSubjectError, subject: arg)

  @doc false
  @spec coerce_predicate(coercible_predicate()) :: predicate
  def coerce_predicate(%IRI{} = iri), do: iri
  def coerce_predicate(iri) when is_atom(iri) or is_binary(iri), do: RDF.iri!(iri)
  def coerce_predicate(arg), do: raise(RDF.Triple.InvalidPredicateError, predicate: arg)

  @doc false
  @spec coerce_object(coericble_object()) :: object
  def coerce_object(%IRI{} = iri), do: iri
  def coerce_object(iri) when is_atom(iri) or is_binary(iri), do: RDF.iri!(iri)
  def coerce_object(arg), do: Literal.new(arg)

  @doc """
  Returns true if `b` is an fragment IRI of `a`.

  ## Examples

    iex> RDF.FragmentGraph.is_fragment(~I<http://example.com>, ~I<http://example.com#something>)
    true
    iex> RDF.FragmentGraph.is_fragment(~I<http://example.com>,~I<http://example.org>)
    false
  """
  @spec is_fragment(RDF.IRI.t(), RDF.IRI.t()) :: boolean()
  def is_fragment(a, b) do
    a_uri = RDF.IRI.parse(a)
    b_uri = RDF.IRI.parse(b)
    %{b_uri | fragment: nil} == a_uri and a_uri != b_uri
  end

  @doc """
  Returns the fragment part of the IRI.
  """
  @spec get_fragment_identifier(RDF.IRI.t()) :: nil | fragment_identifier()
  def get_fragment_identifier(iri) do
    uri = RDF.IRI.parse(iri)
    uri.fragment
  end

  defp find_subject(data) do
    data
    |> RDF.Data.subjects()
    |> Enum.find(nil, fn %RDF.IRI{} = iri ->
      iri |> RDF.IRI.parse() |> Map.get(:fragment) |> is_nil()
    end)
  end

  @doc """
  Create a new RDF Fragment Graph.
  """
  @spec new(RDF.Data.t() | subject | IRI.coercible()) :: t
  def new(data_or_iri)
  def new(%IRI{} = iri), do: %__MODULE__{subject: iri}

  def new(data_or_iri) do
    if RDF.Data.impl_for(data_or_iri) do
      subject = find_subject(data_or_iri)
      add(new(subject), data_or_iri)
    else
      %__MODULE__{subject: IRI.new!(data_or_iri)}
    end
  end

  defp add_to_statements(statements, coercible_predicate, coercible_object) do
    with predicate <- coerce_predicate(coercible_predicate),
         object <- coerce_object(coercible_object) do
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
    with new_statements <- add_to_statements(statements, predicate, object) do
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
             add_to_statements(%{}, predicate, object),
             fn statements -> add_to_statements(statements, predicate, object) end
           ) do
      %{fg | fragments: new_fragments}
    end
  end

  @doc """
  Add statement to `RDF.FragmentGraph`.
  """
  @spec add(t, Statement.t() | [Statement.t()] | RDF.Data.t()) :: t
  def add(fg, statements)

  def add(fg, {predicate, object}),
    do: add(fg, predicate, object)

  def add(%__MODULE__{subject: subject} = fg, {s, p, o}) do
    cond do
      subject == s ->
        add(fg, p, o)

      is_fragment(subject, s) ->
        add_fragment_statement(fg, get_fragment_identifier(s), p, o)

      true ->
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
end
