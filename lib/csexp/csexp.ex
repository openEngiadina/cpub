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

  # Decoder

  defp read_number(binary, digits \\ "") do
    # somebody please show me how to properly use guards
    case binary do
      <<"0">> <> rest ->
        read_number(rest, digits <> "0")

      <<"1">> <> rest ->
        read_number(rest, digits <> "1")

      <<"2">> <> rest ->
        read_number(rest, digits <> "2")

      <<"3">> <> rest ->
        read_number(rest, digits <> "3")

      <<"4">> <> rest ->
        read_number(rest, digits <> "4")

      <<"5">> <> rest ->
        read_number(rest, digits <> "5")

      <<"6">> <> rest ->
        read_number(rest, digits <> "6")

      <<"7">> <> rest ->
        read_number(rest, digits <> "7")

      <<"8">> <> rest ->
        read_number(rest, digits <> "8")

      <<"9">> <> rest ->
        read_number(rest, digits <> "9")

      _ ->
        if String.length(digits) == 0 do
          {:error, :not_a_digit}
        else
          {:ok, String.to_integer(digits), binary}
        end
    end
  end

  defp read_netstring(binary) do
    with {:ok, n, rest} <- read_number(binary) do
      case rest do
        ":" <> <<value::binary-size(n)>> <> rest ->
          {:ok, value, rest}

        _ ->
          {:error, :invalid_netstring}
      end
    end
  end

  defp read_list(binary, elements \\ []) do
    case binary do
      ")" <> rest ->
        {:ok, elements, rest}

      _ ->
        with {:ok, el, rest} <- read_expression(binary) do
          read_list(rest, elements ++ [el])
        end
    end
  end

  defp read_expression(binary) do
    case binary do
      <<"(">> <> rest ->
        read_list(rest)

      <<digit::8>> <> _ when digit > 47 and digit < 58 ->
        read_netstring(binary)

      _ ->
        {:error, :unexpected_byte_value}
    end
  end

  @doc """
  Decode a Canonical S-expression
  """
  def decode(binary) do
    with {:ok, sexp, <<>>} <- read_expression(binary) do
      {:ok, sexp}
    end
  end
end
