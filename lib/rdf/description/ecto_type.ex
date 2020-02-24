defmodule RDF.Description.EctoType do
  @moduledoc """
  Implements the `Ecto.Type` behaviour for `RDF.Description`.

  Serialization is same as for `RDF.Graph.EctoType`. An Ecto field using this type can also be read as `RDF.Graph.EctoType` (but not vice-versa).
  """

  use Ecto.Type

  alias RDF.Description

  def type do
    :map
  end

  @doc false
  def cast(%Description{} = data) do
    {:ok, data}
  end

  def cast(_), do: :error

  def dump(%Description{} = data) do
    RDF.JSON.Encoder.from_rdf(data)
  end

  def load(data) when is_map(data) do
    with {:ok, graph} <- RDF.JSON.Decoder.to_rdf(data) do
      case RDF.Graph.descriptions(graph) do
        [description] ->
          # If the RDF.Graph contains a single description, it is the description we want
          {:ok, description}

        [] ->
          # If no description is in the RDF.Graph we might be able to extract the subject
          load_empty_description(data)

        _ ->
          # If there are multiple descriptions we are probably trying to decode an RDF.Graph.
          {:error, "more than one description in data"}
      end
    end
  end

  defp load_empty_description(data) do
    case Map.keys(data) |> Enum.map(&RDF.IRI.new/1) do
      [subject] ->
        {:ok, RDF.Description.new(subject)}

      _ ->
        # If there is no or multiple possible subject, fail
        {:error, "could not load description"}
    end
  end
end
