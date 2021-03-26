# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.SessionController do
  @moduledoc """
  Handles session creation and deletion (login/logout).
  """

  use CPub.Web, :controller

  alias CPub.User

  alias CPub.Web.Authentication.OAuthClient
  alias CPub.Web.Authentication.Session

  action_fallback CPub.Web.FallbackController

  @spec login(Plug.Conn.t(), map) :: Plug.Conn.t()
  def login(%Plug.Conn{assigns: %{session: _session}} = conn, _params) do
    conn
    |> store_authentication_callback()
    |> authentication_success()
  end

  def login(%Plug.Conn{method: "GET"} = conn, %{"error" => error_msg}) do
    conn
    |> put_flash(:error, error_msg)
    |> render_login()
  end

  def login(%Plug.Conn{method: "GET"} = conn, _params) do
    conn
    |> store_authentication_callback()
    |> render_login()
  end

  @doc """
  Try and figure out if credential is a username, a Fediverse server or an other
  useable identifier and dispatch the proper provider.
  """
  def login(%Plug.Conn{method: "POST"} = conn, %{"credential" => credential}) do
    uri = URI.parse(credential)

    if uri.scheme == "https" do
      login(conn, %{site: credential})
    else
      login(conn, %{username: credential})
    end
  end

  def login(%Plug.Conn{method: "POST"} = conn, %{username: username}) do
    with {:ok, user} <- User.get(username),
         {:ok, registration} <- User.Registration.get_user_registration(user) do
      case registration.provider do
        :internal ->
          params = %{username: username}
          path = Routes.authentication_provider_path(conn, :request, "internal", params)

          redirect(conn, to: path)

        :oidc ->
          params = %{site: registration.site}
          path = Routes.authentication_provider_path(conn, :request, "oidc", params)

          redirect(conn, to: path)

        :mastodon ->
          params = %{site: registration.site}
          path = Routes.authentication_provider_path(conn, :request, "mastodon", params)

          redirect(conn, to: path)
      end
    else
      _ ->
        # if user does not exist still forward to local login
        params = %{username: username}
        path = Routes.authentication_provider_path(conn, :request, "internal", params)

        redirect(conn, to: path)
    end
  end

  def login(%Plug.Conn{method: "POST"} = conn, %{site: site}) do
    params = %{site: site}
    path = Routes.authentication_provider_path(conn, :request, "mastodon", params)

    redirect(conn, to: path)
  end

  @spec render_login(Plug.Conn.t()) :: Plug.Conn.t()
  def render_login(%Plug.Conn{} = conn) do
    with {:ok, clients} <- OAuthClient.get_displayable() do
      render(conn, "login.html",
        callback_url: Routes.authentication_session_path(conn, :login),
        clients: clients
      )
    end
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(%Plug.Conn{assigns: %{session: session}} = conn, _params) do
    with {:ok, user} <- User.get_by_id(session.user) do
      render(conn, "show.html",
        logout_url: Routes.authentication_session_path(conn, :logout),
        username: user.username
      )
    end
  end

  def show(%Plug.Conn{} = conn, _params) do
    redirect(conn, to: Routes.authentication_session_path(conn, :login))
  end

  @spec logout(Plug.Conn.t(), map) :: Plug.Conn.t()
  def logout(%Plug.Conn{assigns: %{session: session}} = conn, _params) do
    _ = Session.delete(session.id)

    conn
    |> clear_session()
    |> authentication_success()
  end

  def logout(%Plug.Conn{} = conn, _params) do
    conn
    |> clear_session()
    |> authentication_success()
  end

  # Create a session, put it in browser session and redirect to the `on_success`
  # param. This is usually the last authentication step.
  @spec create_session(Plug.Conn.t(), User.t()) :: Plug.Conn.t()
  def create_session(%Plug.Conn{} = conn, %User{} = user) do
    with {:ok, session} <- Session.create(user) do
      conn
      |> put_session(:session_id, session.id)
      |> authentication_success()
    end
  end

  # Store a note in the session on where the user should be redirect when
  # authentication succeeds.
  @spec store_authentication_callback(Plug.Conn.t()) :: Plug.Conn.t()
  defp store_authentication_callback(conn) do
    callback =
      conn.params["on_success"] ||
        get_session(conn, :authentication_callback) ||
        Routes.authentication_session_path(conn, :show)

    put_session(conn, :authentication_callback, callback)
  end

  # Redirect to authentication "on success" callback.
  @spec authentication_success(Plug.Conn.t()) :: Plug.Conn.t()
  defp authentication_success(conn) do
    callback =
      get_session(conn, :authentication_callback) ||
        Routes.authentication_session_path(conn, :show)

    conn
    |> delete_session(:authentication_callback)
    |> redirect(to: callback)
  end
end
