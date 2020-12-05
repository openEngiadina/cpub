# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.Signify do
  @moduledoc """
  RDF Signify (http://purl.org/signify/spec).

  Signatures for content-addressed content using an RDF vocabulary.
  """

  use RDF.Vocabulary.Namespace

  defvocab(NS,
    base_iri: "http://purl.org/signify#",
    file: "rdf-signify.ttl"
  )

  alias :monocypher, as: Monocypher

  defmodule PublicKey do
    @moduledoc """
    An Ed25519 public key.
    """
    defstruct [:value]

    @doc """
    Returns the `RDF.IRI` encoding of the `PublicKey` `pk`.
    """
    def to_iri(pk) do
      ("crypto:ed25519:pk:" <> Base.encode32(pk.value, padding: false)) |> RDF.IRI.new()
    end

    @doc """
    Parse `PublicKey` from `RDF.IRI` or a string.
    """
    def parse(%__MODULE__{} = pk), do: {:ok, pk}

    def parse(%RDF.IRI{} = iri) do
      iri
      |> RDF.IRI.to_string()
      |> parse
    end

    def parse("crypto:ed25519:pk:" <> base_encoded) do
      case Base.decode32(base_encoded, padding: false) do
        {:ok, value} ->
          {:ok, %__MODULE__{value: value}}

        _ ->
          {:error, :not_a_valid_public_key}
      end
    end

    def parse(_) do
      {:error, :not_a_valid_public_key}
    end
  end

  defmodule SecretKey do
    @moduledoc """
    A RDF Signify secret key.
    """
    defstruct [:value, :public_key]

    def generate() do
      with secret_key <- :crypto.strong_rand_bytes(32),
           public_key <- Monocypher.crypto_ed25519_public_key(secret_key) do
        %__MODULE__{
          value: secret_key,
          public_key: %PublicKey{value: public_key}
        }
      end
    end
  end

  @doc """
  Signs the `RDF.IRI` `message` with the `SecretKey` `sk` and returns the
  signature as a finalized `RDF.FragmentGraph`.
  """
  def sign(%RDF.IRI{} = message, %SecretKey{} = sk) do
    with signature <- Monocypher.crypto_ed25519_sign(sk.value, sk.public_key.value, message.value) do
      RDF.FragmentGraph.new()
      |> RDF.FragmentGraph.add(RDF.type(), NS.Signature)
      |> RDF.FragmentGraph.add(RDF.value(), RDF.XSD.base64Binary(signature))
      |> RDF.FragmentGraph.add(NS.message(), message)
      |> RDF.FragmentGraph.add(NS.publicKey(), PublicKey.to_iri(sk.public_key))
      |> RDF.FragmentGraph.finalize()
    end
  end

  @doc """
  Verify signature in the `RDF.FragmentGraph` `fg`.
  """
  @spec verify(RDF.FragmentGraph.t()) :: {:ok, RDF.FragmentGraph.t()} | {:error, atom()}
  def verify(%RDF.FragmentGraph{} = fg) do
    with description <- fg[:base_subject],
         [public_key_urn] <- description[NS.publicKey()],
         {:ok, public_key} <- PublicKey.parse(public_key_urn),
         [message] <- description[NS.message()],
         [signature] <- description[RDF.value()] do
      case Monocypher.crypto_ed25519_check(
             signature.literal.value,
             public_key.value,
             RDF.IRI.to_string(message)
           ) do
        :ok ->
          {:ok, fg}

        :forgery ->
          {:error, :invalid_signature}
      end
    else
      _ ->
        {:error, :invalid_signature}
    end
  end
end
