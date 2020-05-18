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
    ("urn:uuid:" <> Ecto.UUID.generate())
    |> RDF.IRI.new()
  end
end
