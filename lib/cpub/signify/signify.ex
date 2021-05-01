# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Signify do
  @moduledoc """
  RDF Signify (http://purl.org/signify/spec).

  Signatures for content-addressed content using an RDF vocabulary.
  """

  use RDF.Vocabulary.Namespace

  alias RDF.FragmentGraph

  alias CPub.DB
  alias CPub.Signify

  alias :monocypher, as: Monocypher

  defvocab(NS,
    base_iri: "http://purl.org/signify#",
    file: "rdf-signify.ttl"
  )

  @type t :: %{
          :id => String.t(),
          required(:message) => String.t(),
          required(:public_key) => String.t()
        }

  defmodule Signature do
    @moduledoc """
    A mnesia table indexing valid signatures.
    """
    use Memento.Table,
      attributes: [:id, :public_key, :message],
      index: [:message],
      type: :set

    @doc """
    Verify signature and add to index if valid.
    """
    @dialyzer {:nowarn_function, insert: 1}
    @spec insert(FragmentGraph.t()) :: {:ok, any} | :invalid_signature
    def insert(%FragmentGraph{} = fg) do
      case CPub.Signify.verify(fg) do
        {:ok, %{message: message, public_key: public_key}} ->
          insert!(fg, public_key, RDF.IRI.to_string(message))

        {:error, _} ->
          :invalid_signature
      end
    end

    @spec insert!(FragmentGraph.t(), String.t(), String.t()) :: {:ok, any} | {:error, any}
    def insert!(fg, public_key, message) do
      DB.transaction(fn ->
        with {:ok, read_capability} <- CPub.ERIS.put(fg),
             {:ok, message_read_capability} <- ERIS.ReadCapability.parse(message) do
          %__MODULE__{
            id: read_capability,
            public_key: Signify.PublicKey.to_iri(public_key),
            message: message_read_capability
          }
          |> DB.write()
        else
          {:error, reason} ->
            DB.abort(reason)

          _ ->
            DB.abort(:can_not_insert_signature)
        end
      end)
    end
  end

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

    def generate do
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
  def sign(%ERIS.ReadCapability{} = read_capability, %SecretKey{} = sk) do
    with message <- read_capability |> ERIS.ReadCapability.to_string(),
         signature <- Monocypher.crypto_ed25519_sign(sk.value, sk.public_key.value, message) do
      {:ok,
       FragmentGraph.new()
       |> FragmentGraph.add(RDF.type(), NS.Signature)
       |> FragmentGraph.add(RDF.value(), RDF.XSD.base64Binary(signature, as_value: true))
       |> FragmentGraph.add(NS.message(), RDF.iri(message))
       |> FragmentGraph.add(NS.publicKey(), PublicKey.to_iri(sk.public_key))
       |> FragmentGraph.finalize(&CPub.Magnet.fragment_graph_finalizer/1)}
    end
  end

  def sign(message, %SecretKey{} = sk) do
    with {:ok, read_capability} <- ERIS.ReadCapability.parse(message) do
      sign(read_capability, sk)
    end
  end

  @doc """
  Verify signature in the `RDF.FragmentGraph` `fg`.
  """
  @spec verify(FragmentGraph.t()) :: {:ok, t} | {:error, atom}
  def verify(%FragmentGraph{} = fg) do
    signature_type = RDF.IRI.new(NS.Signature)

    with description <- fg[:base_subject],
         [^signature_type] <- description[RDF.type()],
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
          {:ok, %{message: message, public_key: public_key}}

        :forgery ->
          {:error, :invalid_signature}
      end
    else
      _ ->
        {:error, :invalid_signature}
    end
  end
end
