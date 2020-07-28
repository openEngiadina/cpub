defmodule RDF.StreamData do
  @moduledoc """
  StreamData generators for RDF data.

  Generation is very basic and limited.
  TODO: Generate nicer RDF data using StreamData.tree
  """

  import StreamData

  alias RDF.{BlankNode, Description, FragmentGraph, Graph, IRI, Literal, Statement, Triple}

  @spec literal :: StreamData.t(Literal.t())
  @dialyzer {:nowarn_function, literal: 0}
  def literal do
    [integer(), string(:printable)]
    |> one_of()
    |> map(&Literal.new/1)
  end

  @spec bnode :: StreamData.t(BlankNode.t())
  @dialyzer {:nowarn_function, bnode: 0}
  def bnode do
    # Note we add ":" to blank node identifier so it gets the same value when
    # deserialized from RDF/JSON.LD. Better would be an equality that can handle
    # mismatch in blank node naming.
    map(positive_integer(), &BlankNode.new/1)
  end

  @spec iri :: StreamData.t(IRI.t())
  @dialyzer {:nowarn_function, iri: 0}
  def iri do
    scheme = one_of([constant("http"), constant("https")])
    host = string(:alphanumeric, max_length: 50)
    path = map(list_of(string(:alphanumeric, max_length: 20), max_length: 6), &Enum.join(&1, "/"))

    {scheme, host, path}
    |> tuple()
    |> map(fn {scheme, host, path} -> IRI.new!("#{scheme}://#{host}/#{path}") end)
  end

  @spec subject :: StreamData.t(Statement.subject())
  @dialyzer {:nowarn_function, subject: 0}
  def subject do
    one_of([iri(), bnode()])
  end

  @spec object :: StreamData.t(Statement.object())
  @dialyzer {:nowarn_function, object: 0}
  def object do
    one_of([iri(), bnode(), literal()])
  end

  @spec predicate :: StreamData.t(Statement.predicate())
  @dialyzer {:nowarn_function, predicate: 0}
  def predicate do
    iri()
  end

  @spec triple :: StreamData.t(Triple.t())
  @dialyzer {:nowarn_function, triple: 0}
  def triple do
    {subject(), predicate(), object()}
    |> tuple()
    |> map(&Triple.new/1)
  end

  @spec description :: StreamData.t(Description.t())
  @dialyzer {:nowarn_function, description: 0}
  def description do
    {subject(), {predicate(), object()} |> list_of(min_length: 1)}
    |> map(fn {subject, predicate_objects} ->
      Enum.reduce(
        predicate_objects,
        Description.new(subject),
        &Description.add(&2, elem(&1, 0), elem(&1, 1))
      )
    end)
  end

  @spec graph :: StreamData.t(Graph.t())
  @dialyzer {:nowarn_function, graph: 0}
  def graph do
    triple()
    |> list_of()
    |> map(&Graph.new/1)
  end

  @spec fragment_graph :: StreamData.t(FragmentGraph.t())
  @dialyzer {:nowarn_function, fragment_graph: 0}
  def fragment_graph do
    base_subject = iri()
    fg_objects = one_of([iri(), literal()]) |> list_of(min_length: 1) |> map(&MapSet.new/1)
    statements = map_of(iri(), fg_objects)
    fragment_statements = map_of(string(:alphanumeric), statements)

    {base_subject, statements, fragment_statements}
    |> map(fn {base_subject, statements, fragment_statements} ->
      %FragmentGraph{
        base_subject: base_subject,
        statements: statements,
        fragment_statements: fragment_statements
      }
    end)
  end
end
