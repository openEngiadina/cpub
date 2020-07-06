defmodule RDF.FragmentGraph.EctoType do
  @moduledoc """
  Implements the `Ecto.Type` behaviour for `RDF.FragmentGraph`.

  Serialization is based on `RDF.FragmentGraph.JSON`.
  """

  use Ecto.Type

  alias RDF.{Description, FragmentGraph}

  @spec type :: :map
  def type, do: :map

  @doc false
  @spec cast(any) :: {:ok, Description.t()} | :error
  def cast(%FragmentGraph{} = data), do: {:ok, data}
  def cast(%Description{} = data), do: {:ok, data |> FragmentGraph.new()}
  def cast(_), do: :error

  @spec dump(FragmentGraph.t()) :: {:ok, map} | :error
  def dump(%FragmentGraph{} = data) do
    FragmentGraph.JSON.from_rdf(data)
  end

  @spec load(map) :: {:ok, FragmentGraph.t()} | :error
  def load(data) do
    FragmentGraph.JSON.to_rdf(data)
  end
end
