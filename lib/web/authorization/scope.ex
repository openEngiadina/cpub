# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authorization.Scope do
  @moduledoc """
  Defines the valid scopes of authorization to CPub.

  Valid scopes are:

  - `:read`
  - `:write`
  - `:follow`

  See [the Mastodon OAuth
  scopes](https://docs.joinmastodon.org/api/oauth-scopes/) for inspiration on
  more finer-grained scopes that might be implemented in the future.
  """

  @valid_scopes [:follow, :openid, :read, :write]

  @spec default :: [atom]
  def default, do: [:read, :write]

  @doc """
  Returns true if `scope1` is a subset of `scope2`
  """
  @spec scope_subset?([atom], [atom]) :: bool
  def scope_subset?(scope1, scope2) do
    MapSet.subset?(MapSet.new(scope1), MapSet.new(scope2))
  end

  @doc """
  Returns true is scope or list of scopes is valid.
  """
  @spec valid?([atom] | atom) :: bool
  def valid?(scope) when is_list(scope), do: Enum.all?(scope, &valid?/1)
  def valid?(scope), do: scope in @valid_scopes

  @spec parse_individual(any) :: atom
  defp parse_individual("follow"), do: :follow
  defp parse_individual(:follow), do: :follow
  defp parse_individual("read"), do: :read
  defp parse_individual(:read), do: :read
  defp parse_individual("write"), do: :write
  defp parse_individual(:write), do: :write
  defp parse_individual(_), do: :invalid

  @doc """
  Parse and validate a string into a list of valid scopes.
  """
  @spec parse(any) :: {:ok, [atom]} | {:error, any}
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
