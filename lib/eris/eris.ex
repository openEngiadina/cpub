defmodule ERIS do
  @moduledoc """
  An Encoding for Robust Immutable Storage

  See https://openengiadina.net/papers/eris.html
  """

  alias ERIS.{Crypto, MerkleTree}

  defprotocol BlockStorage do
    @doc "Store some data and return the hash reference"
    def put(bs, data)

    @doc "Retrieve from block storage"
    def get(bs, ref)
  end

  defmodule BlockStorage.Dummy do
    @moduledoc "A dummy block storage that doesn't store anything. Useful for computing the ERIS capability."

    defstruct []

    def new, do: %__MODULE__{}

    defimpl BlockStorage, for: __MODULE__ do
      def put(dummy, data), do: {:ok, Crypto.hash(data), dummy}

      def get(_dummy, _ref), do: {:error, "not found"}
    end
  end

  defimpl BlockStorage, for: Map do
    def put(map, data) do
      ref = Crypto.hash(data)
      # {:put, ref} |> IO.inspect()
      {:ok, ref, map |> Map.put(ref, data)}
    end

    def get(map, ref) do
      # {:get, ref} |> IO.inspect()

      case Map.get(map, ref) do
        nil ->
          {:error, "not found"}

        data ->
          {:ok, data}
      end
    end
  end

  defmodule Capability do
    @moduledoc """
    An ERIS Capability holding information required to decode/verify ERIS encoded content.
    """
    defstruct version: 0, type: nil, level: nil, root_reference: nil, key: nil

    def encode(%__MODULE__{} = cap) do
      :binary.list_to_bin([cap.version, cap.type, cap.level]) <>
        cap.root_reference <> cap.key
    end

    def to_uri(%__MODULE__{} = cap) do
      %URI{
        scheme: "urn",
        path:
          "erisx:" <>
            (cap
             |> encode
             |> Base.encode32(padding: false))
      }
    end

    def to_string(%__MODULE__{} = cap) do
      cap
      |> to_uri()
      |> URI.to_string()
    end
  end

  def put!(block_storage, data) do
    with padded <- Crypto.pad(data),
         read_key <- Crypto.hash(data),
         encrypted <- Crypto.xor(padded, key: read_key, nonce: <<0::96>>),
         verification_key <- Crypto.derive_verification_key(read_key),
         {level, root_reference, block_storage} <-
           MerkleTree.encode(encrypted,
             verification_key: verification_key,
             block_storage: block_storage
           ) do
      {:ok,
       %Capability{
         version: 0,
         type: 0,
         level: level,
         root_reference: root_reference,
         key: read_key
       }, block_storage}
    end
  end

  def get(block_storage, cap) do
    MerkleTree.decode(cap.root_reference, cap.level, 0,
      verification_key: cap.key |> Crypto.derive_verification_key(),
      block_storage: block_storage
    )
    |> Enum.join()
    |> Crypto.xor(key: cap.key, nonce: <<0::96>>)
    |> Crypto.unpad()
  end
end
