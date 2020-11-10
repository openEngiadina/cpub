defmodule RDF.FragmentGraph.EctoType do
  @moduledoc """
  Implements the `Ecto.Type` behaviour for `RDF.FragmentGraph`.

  Serialization is based on `RDF.FragmentGraph.JSON`.

  TODO This is wrong as it encodes using JSON. It should use the specified CSexp encoding.
  """

  use Ecto.Type

  alias RDF.{Description, FragmentGraph}

  @spec type :: :binary
  def type, do: :binary

  @doc false
  @spec cast(any) :: {:ok, FragmentGraph.t()} | :error
  def cast(%FragmentGraph{} = data), do: {:ok, data}
  def cast(%Description{} = data), do: {:ok, data |> FragmentGraph.new()}
  def cast(_), do: :error

  @spec dump(FragmentGraph.t()) :: {:ok, map} | :error
  def dump(%FragmentGraph{} = data) do
    with {:ok, json} <- FragmentGraph.JSON.from_rdf(data) do
      Jason.encode(json)
    end
  end

  @spec load(map) :: {:ok, FragmentGraph.t()} | :error
  def load(data) do
    Jason.decode!(data)
    |> FragmentGraph.JSON.to_rdf()
  end
end
