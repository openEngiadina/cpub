defmodule RDF.FragmentGraph.EctoType do
  @moduledoc """
  Implements the `Ecto.Type` behaviour for `RDF.FragmentGraph`.

  Stores Fragment Graph as Canonical S-Expression (see `RDF.FragmentGraph.CSexp`).
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
    {:ok, FragmentGraph.CSexp.encode(data)}
  end

  @spec load(map) :: {:ok, FragmentGraph.t()} | :error
  def load(data) do
    with eris_urn <- ERIS.encode_urn(data) |> RDF.IRI.new() do
      {:ok, FragmentGraph.CSexp.decode(data, eris_urn)}
    end
  end
end
