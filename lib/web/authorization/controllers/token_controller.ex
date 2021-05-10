# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authorization.TokenController do
  @moduledoc """
  Implements the OAuth 2.0 Token Endpoint (https://tools.ietf.org/html/rfc6749#section-3.2).
  """

  use CPub.Web, :controller

  import CPub.Web.Authorization.Utils

  alias CPub.User

  alias CPub.Web.Authorization
  alias CPub.Web.Authorization.{Client, Scope, Token}
  alias CPub.Web.Path

  action_fallback CPub.Web.Authorization.FallbackController

  @spec token(Plug.Conn.t(), map) :: Plug.Conn.t() | {:error, any, any}
  def token(%Plug.Conn{} = conn, %{"grant_type" => "authorization_code"}) do
    with {:ok, %Client{} = client} <- get_client(conn),
         {:ok, authorization} <-
           get_authorization(conn, %{grant_type: :authorization_code, client: client}),
         {:ok, false} <- check_code_used(authorization),
         {:ok, true} <- check_redirect_uri(conn, client),
         {:ok, token} <- Token.create(authorization),
         {:ok, %User{} = user} <- User.get_by_id(authorization.user) do
      conn
      |> put_status(:ok)
      |> put_view(JSONView)
      |> render(:show,
        data: %{
          access_token: token.access_token,
          token_type: "bearer",
          expires_in: Token.valid_for(),
          refresh_token: authorization.refresh_token,
          # IndieAuth: https://indieauth.spec.indieweb.org/#access-token-response
          me: Path.user(user)
        }
      )
    end
  end

  def token(%Plug.Conn{} = conn, %{"grant_type" => "refresh_token"}) do
    with {:ok, authorization} <- get_authorization(conn, %{grant_type: :refresh_token}),
         {:ok, token} <- Token.refresh(authorization),
         {:ok, %User{} = user} <- User.get_by_id(authorization.user) do
      conn
      |> put_status(:ok)
      |> put_view(JSONView)
      |> render(:show,
        data: %{
          access_token: token.access_token,
          token_type: "bearer",
          expires_in: Token.valid_for(),
          refresh_token: authorization.refresh_token,
          # IndieAuth: https://indieauth.spec.indieweb.org/#access-token-response
          me: Path.user(user)
        }
      )
    end
  end

  def token(%Plug.Conn{} = conn, %{"grant_type" => "password"} = params) do
    with {:ok, user} <- User.get(params["username"]),
         {:ok, registration} <- User.Registration.get_user_registration(user),
         :ok <- User.Registration.check_internal(registration, params["password"]),
         {:ok, scope} <- Scope.parse(Map.get(params, "scope", Scope.default())),
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
          refresh_token: authorization.refresh_token,
          # IndieAuth: https://indieauth.spec.indieweb.org/#access-token-response
          me: Path.user(user)
        }
      )
    else
      _ ->
        {:error, :invalid_grant, "unauthorized"}
    end
  end

  def token(%Plug.Conn{} = _conn, %{"grant_type" => _}) do
    {:error, :unsupported_grant_type, "unsupported grant_type."}
  end

  @spec get_authorization(Plug.Conn.t(), map) :: {:ok, Authorization.t()} | {:error, any, any}
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

  @spec check_code_used(Authorization.t()) :: {:ok, bool} | {:error, atom, String.t()}
  defp check_code_used(%Authorization{code_used: false}), do: {:ok, false}
  defp check_code_used(%Authorization{code_used: true}), do: {:error, :code_used, "used code"}

  @spec check_redirect_uri(Plug.Conn.t(), Client.t()) :: {:ok, bool} | {:error, atom, String.t()}
  defp check_redirect_uri(%Plug.Conn{} = conn, %Client{} = client) do
    case conn.params["redirect_uri"] in client.redirect_uris do
      true ->
        {:ok, true}

      false ->
        {:error, :redirect_uri_masmatch, "redirect URI mismatch"}
    end
  end
end
