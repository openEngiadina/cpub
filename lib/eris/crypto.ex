defmodule ERIS.Crypto do
  @moduledoc """
  Wrapper around OTP :crypto that provides convenient access to the ChaCha20
  stream cypher.

  See also the documentation of the Erlang OTP :crypto module
  (http://erlang.org/doc/apps/crypto/algorithm_details.html#ciphers).
  """

  @doc """
  XOR the `data` with the ChaCha20 stream for `key` and `nonce`.

  The `key` needs to be a bitstring of size 256 bits. The `nonce` needs to be a bitstring of size 96 bits.

  See also https://tools.ietf.org/html/rfc8439
  """
  def xor(data, key: key, nonce: nonce) do
    # First 32 bits of IV are the counter and the rest (96 bits) the nonce.
    # See https://www.openssl.org/docs/man1.1.1/man3/EVP_chacha20_poly1305.html
    iv = <<0::32>> <> nonce
    :crypto.crypto_one_time(:chacha20, key, iv, data, true)
  end

  @doc """
  Pad data
  """
  def pad(data, opts \\ []) do
    block_size = Keyword.get(opts, :block_size, 4096)
    data_size = byte_size(data)
    pad_len = ((div(data_size, block_size) + 1) * block_size - data_size - 1) * 8
    data <> <<0x80::8>> <> <<0::size(pad_len)>>
  end

  defp unpad_loop(data) do
    data_size = byte_size(data)

    case binary_part(data, data_size, -1) do
      <<0x00>> -> unpad_loop(binary_part(data, 0, data_size - 1))
      <<0x80>> -> binary_part(data, 0, data_size - 1)
      _ -> raise("invalid padding")
    end
  end

  @doc """
  Unpad data
  """
  def unpad(data, opts \\ []) do
    block_size = Keyword.get(opts, :block_size, 4096)
    data_size = byte_size(data)

    if data_size < block_size or rem(data_size, block_size) != 0 or block_size <= 0,
      do: raise("argument error")

    unpad_loop(data)
  end
end
