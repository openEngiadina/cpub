defmodule RDF.Description.EctoType do
  @moduledoc """
  Implements the `Ecto.Type` behaviour for `RDF.Description`.

  Serialization is same as for `RDF.Graph.EctoType`.
  An Ecto field using this type can also be read as `RDF.Graph.EctoType` (but not vice-versa).
  """

  use Ecto.Type

  alias RDF.{Description, Graph, IRI, JSON}

  @spec type :: :map
  def type, do: :map

  @doc false
  @spec cast(Description.t() | any) :: {:ok, Description.t()} | :error
  def cast(%Description{} = data), do: {:ok, data}
  def cast(_), do: :error

  @spec dump(Description.t()) ::
          {:ok, %{String.t() => %{String.t() => [JSON.Encoder.value_object()]}}}
  def dump(%Description{} = data) do
    JSON.Encoder.from_rdf(data)
  end

  @spec load(%{String.t() => %{String.t() => [JSON.Decoder.object()]}}) ::
          {:ok, Description.t()} | :error
  def load(data) when is_map(data) do
    with {:ok, graph} <- JSON.Decoder.to_rdf(data) do
      case Graph.descriptions(graph) do
        [description] ->
          # If the RDF.Graph contains a single description, it is the description we want
          {:ok, description}

        [] ->
          # If no description is in the RDF.Graph we might be able to extract the subject
          load_empty_description(data)

        _ ->
          # If there are multiple descriptions we are probably trying to decode an RDF.Graph.
          :error
      end
    end
  end

  @spec load_empty_description(%{String.t() => %{String.t() => [JSON.Decoder.object()]}}) ::
          {:ok, Description.t()} | :error
  defp load_empty_description(data) do
    case Map.keys(data) |> Enum.map(&IRI.new/1) do
      [subject] ->
        {:ok, Description.new(subject)}

      _ ->
        # If there is no or multiple possible subject, fail
        :error
    end
  end
end
