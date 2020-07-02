defmodule RDF.FragmentGraph.EctoType do
  @moduledoc """
  Implements the `Ecto.Type` behaviour for `RDF.Description`.

  Serialization is based on `RDF.Graph.EctoType`.
  An Ecto field using this type can also be read as `RDF.Graph.EctoType` (but not vice-versa).
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
