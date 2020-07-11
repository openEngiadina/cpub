defmodule Crypto.ChaCha20 do
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
end
