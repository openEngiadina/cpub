defmodule RDF.StreamData do
  @moduledoc """
  StreamData generators for RDF data.

  Generation is very basic and limited.
  TODO: Generate nicer RDF data using StreamData.tree
  """

  import StreamData

  def literal do
    [integer(), string(:printable)]
    |> one_of()
    |> map(&RDF.Literal.new/1)
  end

  def bnode do
    # Note we add ":" to blank node identifier so it gets the same value when deserialized from RDF/JSON.LD.
    # Better would be an equality that can handle mismatch in blank node naming.
    map(positive_integer(), &RDF.BlankNode.new/1)
  end

  def iri do
    scheme = one_of([constant("http"), constant("https")])
    host = string(:alphanumeric)
    path = map(list_of(string(:alphanumeric)), &Enum.join(&1, "/"))

    {scheme, host, path}
    |> tuple()
    |> map(fn {scheme, host, path} -> RDF.IRI.new!("#{scheme}://#{host}/#{path}") end)
  end

  def subject do
    one_of([iri(), bnode()])
  end

  def object do
    one_of([iri(), bnode(), literal()])
  end

  def predicate do
    iri()
  end

  def triple do
    {subject(), predicate(), object()}
    |> tuple()
    |> map(&RDF.Triple.new/1)
  end

  def description do
    {subject(), {predicate(), object()} |> list_of}
    |> map(fn {subject, predicate_objects} ->
      Enum.reduce(
        predicate_objects,
        RDF.Description.new(subject),
        &RDF.Description.add(&2, elem(&1, 0), elem(&1, 1))
      )
    end)
  end

  def graph do
    triple()
    |> list_of()
    |> map(&RDF.Graph.new/1)
  end
end
