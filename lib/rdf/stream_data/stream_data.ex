defmodule RDF.StreamData do
  @moduledoc """
  StreamData generators for RDF data.

  Generation is very basic and limited.
  TODO: Generate nicer RDF data using StreamData.tree
  """

  import StreamData

  alias RDF.{BlankNode, Description, Graph, IRI, Literal, Statement, Triple}

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
    host = string(:alphanumeric)
    path = map(list_of(string(:alphanumeric)), &Enum.join(&1, "/"))

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
    {subject(), {predicate(), object()} |> list_of}
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
end
