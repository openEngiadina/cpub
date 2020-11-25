defmodule CPub.Web.Authorization.TokenController do
  @moduledoc """
  Implements the OAuth 2.0 Token Endpoint (https://tools.ietf.org/html/rfc6749#section-3.2).
  """

  use CPub.Web, :controller

  action_fallback CPub.Web.Authorization.FallbackController

  import CPub.Web.Authorization.Utils

  alias CPub.User

  alias CPub.Web.Authorization
  alias CPub.Web.Authorization.{Scope, Token}

  defp get_authorization(%Plug.Conn{} = conn, %{grant_type: :authorization_code, client: client}) do
    with {:ok, authorization} <- Authorization.get_by_code(conn.params["code"]),
         true <- authorization.client == client.id do
      {:ok, authorization}
    else
      _ ->
        {:error, :invalid_grant, "invalid code"}
    end
  end

  defp get_authorization(%Plug.Conn{} = conn, %{grant_type: :refresh_token}) do
    case Authorization.get_by_refresh_token(conn.params["refresh_token"]) do
      {:ok, authorization} ->
        {:ok, authorization}

      _ ->
        {:error, :invalid_grant, "invalid refresh token"}
    end
  end

  def token(%Plug.Conn{} = conn, %{} = _params) do
    case Map.get(conn.params, "grant_type") do
      "authorization_code" ->
        with {:ok, client} <- get_client(conn),
             # TODO make sure client is authenticated
             # TODO ensure redirect_uri is set
             {:ok, authorization} <-
               get_authorization(conn, %{grant_type: :authorization_code, client: client}),
             {:ok, token} <- Token.create(authorization) do
          conn
          |> put_status(:ok)
          |> put_view(JSONView)
          |> render(:show,
            data: %{
              access_token: token.access_token,
              token_type: "bearer",
              expires_in: Token.valid_for(),
              refresh_token: authorization.refresh_token
            }
          )
        end

      "refresh_token" ->
        with {:ok, authorization} <-
               get_authorization(conn, %{grant_type: :refresh_token}),
             {:ok, token} <-
               Token.refresh(authorization) do
          conn
          |> put_status(:ok)
          |> put_view(JSONView)
          |> render(:show,
            data: %{
              access_token: token.access_token,
              token_type: "bearer",
              expires_in: Token.valid_for(),
              refresh_token: authorization.refresh_token
            }
          )
        end

      "password" ->
        with {:ok, user} <- User.get(conn.params["username"]),
             {:ok, registration} <- User.Registration.get_user_registration(user),
             :ok <- User.Registration.check_internal(registration, conn.params["password"]),
             {:ok, scope} <- Scope.parse(Map.get(conn.params, "scope", Scope.default())),
             {:ok, authorization} <- Authorization.create(user, scope),
             {:ok, token} <- Token.create(authorization) do
          conn
          |> put_status(:ok)
          |> put_view(JSONView)
          |> render(:show,
            data: %{
              access_token: token.access_token,
              token_type: "bearer",
              expires_in: Token.valid_for(),
              refresh_token: authorization.refresh_token
            }
          )
        else
          _ ->
            {:error, :invalid_grant, "unauthorized"}
        end

      _ ->
        {:error, :unsupported_grant_type, "unsupported grant_type."}
    end
  end
end
