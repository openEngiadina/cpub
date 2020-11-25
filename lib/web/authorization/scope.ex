# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authorization.Scope do
  @moduledoc """
  Defines the valid scopes of authorization to CPub.

  Valid scopes are:

  - `:read`
  - `:write`

  See [the Mastodon OAuth
  scopes](https://docs.joinmastodon.org/api/oauth-scopes/) for inspiration on
  more finer-grained scopes that might be implemented in the future.
  """

  @valid_scopes [:openid, :read, :write]

  def default, do: [:read, :write]

  @doc """
  Returns true if `scope1` is a subset of `scope2`
  """
  def scope_subset?(scope1, scope2) do
    MapSet.subset?(MapSet.new(scope1), MapSet.new(scope2))
  end

  @doc """
  Returns true is scope or list of scopes is valid.
  """
  def valid?(scope) when is_list(scope), do: Enum.all?(scope, &valid?/1)
  def valid?(scope), do: scope in @valid_scopes

  defp parse_individual("read"), do: :read
  defp parse_individual(:read), do: :read
  defp parse_individual("write"), do: :write
  defp parse_individual(:write), do: :write
  defp parse_individual(_), do: :invalid

  @doc """
  Parse and validate a string into a list of valid scopes.
  """
  def parse(scope) when is_binary(scope) do
    scope
    |> String.split()
    |> Enum.map(&parse_individual/1)
    |> parse()
  end

  def parse(scope) when is_list(scope) do
    with scope <- Enum.map(scope, &parse_individual/1) do
      if valid?(scope) do
        {:ok, scope}
      else
        {:error, :invalid_scope}
      end
    end
  end

  def parse(_), do: {:error, :invalid_scope}
end
