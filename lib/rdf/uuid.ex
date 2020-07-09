defmodule RDF.UUID do
  @moduledoc """
  Generate UUID URNs.

  See RFC 4122 (https://tools.ietf.org/html/rfc4122).
  """

  @doc """
  Generate a version 4 (random) UUID as a `RDF.IRI`.
  """
  @spec generate() :: RDF.IRI.t()
  def generate do
    ("urn:uuid:" <> UUID.uuid4())
    |> RDF.IRI.new()
  end

  def cast(uuid) when is_binary(uuid) do
    with {:ok, uuid_info} <- UUID.info(uuid) do
      {:ok,
       ("urn:uuid:" <> uuid_info[:uuid])
       |> RDF.IRI.new()}
    end
  end

  def to_string(%RDF.IRI{} = iri) do
    case RDF.IRI.to_string(iri) do
      "urn:uuid:" <> uuid ->
        {:ok, uuid}

      _ ->
        {:error, :invalid_uuid_urn}
    end
  end
end
