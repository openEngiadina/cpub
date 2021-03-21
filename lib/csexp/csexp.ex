# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CSexp do
  @moduledoc """
  Canonical S-expressions.
  """

  @type t :: list

  @doc """
  Encode a S-expression (nested list of strings) as a Canonical S-expression.
  """
  @spec encode(atom | String.t() | {:encoded_csexp, String.t()} | t) :: String.t()
  def encode(str) when is_binary(str), do: "#{str |> byte_size |> to_string}:#{str}"
  def encode(atom) when is_atom(atom), do: atom |> to_string() |> encode()
  def encode({:encoded_csexp, csexp}), do: csexp

  def encode(lst) when is_list(lst) do
    with str <- Enum.map_join(lst, "", &encode/1), do: "(#{str})"
  end

  @doc """
  Decode a Canonical S-expression
  """
  @spec decode(String.t()) :: {:ok, t}
  def decode(binary) when is_binary(binary) do
    with {:ok, sexp, <<>>} <- read_expression(binary), do: {:ok, sexp}
  end

  @spec read_expression(String.t()) :: {:ok, t, String.t()} | {:error, atom}
  defp read_expression(binary) when is_binary(binary) do
    case binary do
      <<"(">> <> rest ->
        read_list(rest)

      <<digit::8>> <> _ when digit > 47 and digit < 58 ->
        read_netstring(binary)

      _ ->
        {:error, :unexpected_byte_value}
    end
  end

  @spec read_list(String.t(), t) :: {:ok, t, String.t()} | {:error, atom}
  defp read_list(binary, elements \\ []) when is_list(elements) do
    case binary do
      ")" <> rest ->
        {:ok, elements, rest}

      _ ->
        with {:ok, el, rest} <- read_expression(binary) do
          read_list(rest, elements ++ [el])
        end
    end
  end

  # Decoder
  # credo:disable-for-next-line
  @spec read_number(String.t(), String.t()) :: {:ok, number, String.t()} | {:error, atom}
  defp read_number(binary, digits \\ "") when is_binary(binary) do
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

  @spec read_netstring(String.t()) :: {:ok, String.t(), String.t()} | {:error, atom}
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
end
