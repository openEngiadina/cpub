defmodule CSexp do
  @moduledoc """
  Canonical S-expressions.
  """

  @doc """
  Encode a S-expression (nested list of strings) as a Canonical S-expression.
  """
  def encode(atom) when is_binary(atom), do: to_string(byte_size(atom)) <> ":" <> atom
  def encode(atom) when is_atom(atom), do: encode(to_string(atom))
  def encode({:encoded_csexp, csexp}), do: csexp
  def encode(lst) when is_list(lst), do: "(" <> Enum.map_join(lst, "", &encode/1) <> ")"
end
