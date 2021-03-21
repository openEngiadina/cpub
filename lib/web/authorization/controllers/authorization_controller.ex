# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authorization.AuthorizationController do
  @moduledoc """
  Implements the OAuth 2.0 Authorization Endpoint
  (https://tools.ietf.org/html/rfc6749#section-3.1).
  """

  use CPub.Web, :controller

  import CPub.Web.Authorization.Utils

  alias CPub.User

  alias CPub.Web.Authorization

  plug :fetch_flash

  action_fallback CPub.Web.Authorization.FallbackController

  # allow `FallbackController` to redirect to redirect_uri with error
  plug :set_oauth_redirect_on_error

  @spec set_oauth_redirect_on_error(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  defp set_oauth_redirect_on_error(%Plug.Conn{} = conn, _opts) do
    assign(conn, :oauth_redirect_on_error, true)
  end

  @doc """
  Check what OAuth 2.0 flow we are in and delegate.
  """
  @spec authorize(Plug.Conn.t(), map) :: Plug.Conn.t()
  def authorize(%Plug.Conn{} = conn, params) do
    case Map.get(conn.params, "response_type") do
      "code" ->
        authorize(:code, conn, params)

      _ ->
        {:error, :unsupported_response_type, "grant type not supported."}
    end
  end

  # Display a interface where user is asked to accept or deny the authorization request.
  @spec authorize(atom, Plug.Conn.t(), map) :: Plug.Conn.t()
  defp authorize(
         response_type,
         %Plug.Conn{method: "GET", assigns: %{session: session}} = conn,
         _params
       ) do
    with {:ok, user} <- User.get_by_id(session.user),
         {:ok, client} <- get_client(conn),
         {:ok, redirect_uri} <-
           get_redirect_uri(fetch_query_params(conn), client),
         {:ok, scope} <- get_scope(conn, client),
         {:ok, state} <- get_state(conn) do
      render(conn, "authorize.html", %{
        client: client,
        oauth_params: %{
          client_id: client.id,
          response_type: response_type,
          redirect_uri: redirect_uri |> URI.to_string(),
          scope: scope |> Enum.map(&to_string/1),
          state: state
        },
        user: user
      })
    end
  end

  # request accepted
  defp authorize(
         :code,
         %Plug.Conn{method: "POST", assigns: %{session: session}} = conn,
         %{"request_accepted" => _params}
       ) do
    with {:ok, user} <- User.get_by_id(session.user),
         {:ok, client} <- get_client(conn),
         {:ok, redirect_uri} <- get_redirect_uri(conn, client),
         {:ok, scope} <- get_scope(conn, client),
         {:ok, state} <- get_state(conn),
         {:ok, authorization} <- Authorization.create(user, client, scope) do
      cb_uri =
        redirect_uri
        |> Map.put(
          :query,
          URI.encode_query(%{code: authorization.authorization_code, state: state})
        )
        |> URI.to_string()

      conn
      |> redirect(external: cb_uri)
    end
  end

  # request denied
  defp authorize(
         _,
         %Plug.Conn{method: "POST"} = _conn,
         %{"request_denied" => _params}
       ) do
    {:error, :access_denied, "access denied"}
  end

  # If there is no session redirect user to login
  defp authorize(
         _,
         %Plug.Conn{method: "GET"} = conn,
         _params
       ) do
    # get and validate all required field so that user is not sent to login
    # if request is invalid in first place
    with {:ok, client} <- get_client(conn),
         {:ok, _redirect_uri} <-
           get_redirect_uri(fetch_query_params(conn), client),
         {:ok, _scope} <- get_scope(conn, client),
         {:ok, _state} <- get_state(conn) do
      redirect(conn,
        to:
          Routes.authentication_session_path(conn, :login, %{
            "on_success" =>
              Routes.oauth_server_authorization_path(conn, :authorize, conn.query_params)
          })
      )
    end
  end
end
