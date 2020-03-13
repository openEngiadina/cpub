defmodule RDF.Graph.EctoType do
  @moduledoc """
  Implements the `Ecto.Type` behaviour for `RDF.Graph`.

  This allows storage of RDF data in a `:map` field. RDF is serialized as RDF/JSON for storage.
  """

  use Ecto.Type

  alias RDF.{Graph, JSON}

  @spec type :: :map
  def type, do: :map

  @doc false
  @spec cast(Graph.t() | any) :: {:ok, Graph.t()} | :error
  def cast(%Graph{} = data), do: {:ok, data}
  def cast(_), do: :error

  @spec dump(Graph.t()) ::
          {:ok, %{String.t() => %{String.t() => [JSON.Encoder.value_object()]}}}
  def dump(%Graph{} = data) do
    JSON.Encoder.from_rdf(data)
  end

  @spec load(%{String.t() => %{String.t() => [JSON.Decoder.object()]}}) ::
          {:ok, Graph.t()} | :error
  def load(data) when is_map(data) do
    JSON.Decoder.to_rdf(data)
  end
end
