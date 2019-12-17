defmodule RDF.Graph.EctoType do
  @moduledoc """
  Implements the `Ecto.Type` behaviour for `RDF.Graph`.

  This allows storage of RDF data in a `:map` field. RDF is serialized as RDF/JSON for storage.
  """

  use Ecto.Type

  alias RDF.Graph

  def type do
    :map
  end

  @doc false
  def cast(%Graph{} = data) do
    {:ok, data}
  end

  def cast(_), do: :error

  def dump(%Graph{} = data) do
    RDF.JSON.Encoder.from_rdf(data)
  end

  def load(data) when is_map(data) do
    RDF.JSON.Decoder.to_rdf(data)
  end

end
