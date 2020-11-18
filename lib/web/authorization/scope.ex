defmodule CPub.Web.Authorization.Scope do
  @doc """
  Defines the valid scopes of authorization to CPub.

  Valid scopes are:

  - `:read`
  - `:write`

  See [the Mastodon OAuth
  scopes](https://docs.joinmastodon.org/api/oauth-scopes/) for inspiration on
  more finer-grained scopes that might be implemented in the future.
  """

  @valid_scopes [:read, :write]

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

  @doc """
  Parse and validate a string into a list of valid scopes.
  """
  def parse(scopes) when is_binary(scopes) do
    with parsed <- scopes |> String.split() |> Enum.map(&String.to_existing_atom/1) do
      if valid?(parsed) do
        {:ok, scopes}
      else
        {:error, :invalid_scopes}
      end
    end
  end

  def parse(_), do: {:error, :invalid_scopes}
end
