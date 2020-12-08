# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.DMC do
  @moduledoc """
  Distributed Mutable Containers (http://purl.org/dmc/spec).
  """
  use RDF.Vocabulary.Namespace

  defvocab(NS,
    base_iri: "http://purl.org/dmc#",
    file: "dmc.ttl"
  )

  defmodule Identifier do
    @moduledoc """
    Helper module for parsing DMC identifiers to `ERIS.ReadCapability`.
    """
    def parse(%ERIS.ReadCapability{} = read_capability), do: {:ok, read_capability}
    def parse(%RDF.IRI{} = iri), do: parse(RDF.IRI.to_string(iri))
    def parse("dmc:" <> base32), do: ERIS.ReadCapability.parse("urn:erisx2:" <> base32)
    def parse(_), do: {:error, :invalid_dmc_identifier}

    def to_iri(%ERIS.ReadCapability{} = read_capability) do
      with "urn:erisx2:" <> base32 <- ERIS.ReadCapability.to_string(read_capability) do
        ("dmc:" <> base32)
        |> RDF.IRI.new()
      end
    end
  end

  defmodule Definition do
    @moduledoc """
    DMC Container definition.

    This modules provides helpers for getting container definitions.
    """

    defstruct [:id, :type, :root_public_key]

    def get(id) do
      with {:ok, read_capability} <- Identifier.parse(id),
           {:ok, fg} <- CPub.ERIS.get_rdf(read_capability),
           description <- fg[:base_subject],
           [%RDF.IRI{} = type] <- description[RDF.type()],
           [%RDF.IRI{} = root_public_key] <- description[NS.rootPublicKey()] do
        {:ok,
         %__MODULE__{
           id: read_capability,
           type: type,
           root_public_key: root_public_key
         }}
      else
        {:error, reason} ->
          {:error, reason}

        _ ->
          {:error, :invalid_dmc_container_definition}
      end
    end
  end
end
