defmodule RDF.StreamData do
  @moduledoc """
  StreamData generators for RDF data.

  Generation is very basic and limited.
  TODO: Generate nicer RDF data using StreamData.tree
  """

  import StreamData

  def literal() do
    one_of([integer(), string(:printable)])
    |> map(&RDF.Literal.new/1)
  end

  def bnode() do
    # note we add ":" to blank node identifier so it gets the same value when deserialized from RDF/JSON.LD. Better would be an equality that can handle mismatch in blank node naming.
    positive_integer()
    |> map(&RDF.BlankNode.new/1)
  end

  def iri() do
    scheme = one_of([constant("http"), constant("https")])
    host = string(:alphanumeric)
    path =  map(list_of(string(:alphanumeric)), &(Enum.join(&1, "/")))

    tuple({scheme, host, path})
    |> map(fn {scheme, host, path} ->
      scheme <> "://" <> host <> "/" <> path
      |> RDF.IRI.new!
    end)
  end

  def subject() do
    one_of([iri(), bnode()])
  end

  def object() do
    one_of([iri(), bnode(), literal()])
  end

  def predicate() do
    iri()
  end

  def triple() do
    tuple({subject(), predicate(), object()})
    |> map(&RDF.Triple.new/1)
  end

  def graph() do
    list_of(triple())
    |> map(&RDF.Graph.new/1)
  end

end
