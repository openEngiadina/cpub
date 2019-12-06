defmodule RDF.EctoType do
  @moduledoc """
  Implement Ecto.Type for RDF.Data by storing data encoded as RDF/JSON in a :map.
  """

  use Ecto.Type

  def type do
    :map
  end

  def cast(data) do
    if is_rdf_data?(data) do
      {:ok, data}
    else
      {:error, "data is not RDF"}
    end
    {:ok, data}
  end

  def dump(data) do
    RDF.JSON.Encoder.from_rdf(data)
  end

  def load(data) when is_map(data) do
    RDF.JSON.Decoder.to_rdf(data)
  end

  defp is_rdf_data?(data) do
    data
    |> RDF.Data.impl_for()
    |> is_nil()
    |> Kernel.not
  end

end
