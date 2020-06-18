defmodule CPub.Web.OAuth.Token.Strategy.RefreshToken do
  @moduledoc """
  Functions for dealing with refresh token strategy.
  """

  alias CPub.{Config, Repo}
  alias CPub.Web.OAuth.Token
  alias CPub.Web.OAuth.Token.Strategy.Revoke

  @spec grant(Token.t()) :: {:ok, Token.t()} | {:error, any}
  def grant(%Token{} = token) do
    %Token{app: app, user: user, scopes: scopes} = Repo.preload(token, [:user, :app])

    result =
      Repo.transaction(fn ->
        token_params = %{app: app, user: user, scopes: scopes}

        token
        |> Revoke.revoke()
        |> create_access_token(token_params)
      end)

    case result do
      {:ok, {:error, reason}} -> {:error, reason}
      {:ok, {:ok, token}} -> {:ok, token}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec create_access_token({:ok, Token.t()} | {:error, any}, map) ::
          {:ok, Token.t()} | {:error, Ecto.Changeset.t()}
  defp create_access_token({:error, error}, _), do: {:error, error}

  defp create_access_token({:ok, token}, %{app: app, user: user} = token_params) do
    Token.create_token(app, user, add_refresh_token(token_params, token.refresh_token))
  end

  @spec add_refresh_token(map, String.t()) :: map
  defp add_refresh_token(params, refresh_token) do
    case Config.auth_issue_new_refresh_token() do
      true -> Map.put(params, :refresh_token, refresh_token)
      false -> params
    end
  end
end
