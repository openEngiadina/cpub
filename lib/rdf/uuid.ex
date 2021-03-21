# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.UUID do
  @moduledoc """
  Generate UUID URNs.

  See RFC 4122 (https://tools.ietf.org/html/rfc4122).
  """

  @doc """
  Generate a version 4 (random) UUID as a `RDF.IRI`.
  """
  @spec generate :: RDF.IRI.t()
  def generate do
    ("urn:uuid:" <> UUID.uuid4())
    |> RDF.IRI.new()
  end

  @spec cast!(String.t()) :: RDF.IRI.t()
  def cast!(uuid) when is_binary(uuid) do
    case cast(uuid) do
      {:ok, out} -> out
      _ -> raise {:error, :invalid_uuid}
    end
  end

  @spec cast(String.t()) :: {:ok, RDF.IRI.t()} | {:error, any}
  def cast(uuid) when is_binary(uuid) do
    with {:ok, uuid_info} <- UUID.info(uuid) do
      {:ok,
       ("urn:uuid:" <> uuid_info[:uuid])
       |> RDF.IRI.new()}
    end
  end

  @spec to_string(RDF.IRI.t()) :: {:ok, String.t()} | {:error, atom}
  def to_string(%RDF.IRI{} = iri) do
    case RDF.IRI.to_string(iri) do
      "urn:uuid:" <> uuid ->
        {:ok, uuid}

      _ ->
        {:error, :invalid_uuid_urn}
    end
  end
end
