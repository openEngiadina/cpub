defmodule CPub.Crypto do
  @moduledoc """
  Functions related to cryptography.
  """

  @doc """
  Returns a random string of a given length.
  """
  @spec random_string(integer) :: String.t()
  def random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, length)
  end
end