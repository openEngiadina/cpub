defmodule CPub.Web.OAuthServer.TokenController do
  @moduledoc """
  Implements the OAuth 2.0 Token Endpoint (https://tools.ietf.org/html/rfc6749#section-3.2).
  """

  use CPub.Web, :controller

  action_fallback CPub.Web.OAuthServer.FallbackController

  import CPub.Web.OAuthServer.Utils

  alias CPub.Repo

  alias CPub.Web.OAuthServer.Authorization
  alias CPub.Web.OAuthServer.Client
  alias CPub.Web.OAuthServer.Token

  defp get_grant_type(%Plug.Conn{} = conn) do
    case Map.get(conn.params, "grant_type") do
      "authorization_code" ->
        :authorization_code

      _ ->
        {:error, :unsupported_grant_type, "unsupported grant_type."}
    end
  end

  def get_authorization(%Plug.Conn{} = conn, client) do
    case Repo.get_one_by(Authorization, %{code: conn.params["code"]}) do
      {:ok, authorization} ->
        if authorization.client_id == client.id do
          {:ok, authorization}
        else
          {:error, :invalid_grant, "invalid code"}
        end

      {:error, _} ->
        {:error, :invalid_grant, "invalid code"}
    end
  end

  def token(%Plug.Conn{} = conn, %{} = _params) do
    with {:ok, client} <- get_client(conn),
         {:ok, authorization} <- get_authorization(conn, client) do
      case get_grant_type(conn) do
        :authorization_code ->
          with {:ok, token} <- Token.create(authorization) do
            conn
            |> put_status(:ok)
            |> put_view(JSONView)
            |> render(:show,
              data: %{
                access_token: token.access_token,
                expires_in: Token.valid_for(),
                refresh_token: authorization.refresh_token
              }
            )
          end
      end
    end
  end
end
