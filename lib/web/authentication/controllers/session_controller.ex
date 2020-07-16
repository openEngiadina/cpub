defmodule CPub.Web.Authentication.SessionController do
  @moduledoc """
  Handles session creation and deletion (login/logout).
  """

  use CPub.Web, :controller

  alias CPub.Repo
  alias CPub.User
  alias CPub.Web.Authentication.Session
  alias CPub.Web.Authentication.Registration

  action_fallback CPub.Web.FallbackController

  def login(%Plug.Conn{assigns: %{session: session}} = conn, _params) do
    conn
    |> redirect(to: on_success(conn))
  end

  def login(%Plug.Conn{method: "GET"} = conn, %{"error" => error_msg}) do
    conn
    |> put_flash(:error, error_msg)
    |> render_login()
  end

  def login(%Plug.Conn{method: "GET"} = conn, _params) do
    conn
    |> render_login()
  end

  def login(%Plug.Conn{method: "POST"} = conn, %{
        "username" => username,
        "on_success" => on_success
      }) do
    params =
      conn.params
      |> Map.take(["username", "on_success"])

    with {:ok, user} <- Repo.get_one_by(User, %{username: username}),
         user <- user |> Repo.preload(:registration) do
      case user.registration do
        %Registration{provider: provider} ->
          conn
          |> redirect(to: Routes.authentication_provider_path(conn, :request, provider, params))

        nil ->
          conn
          |> redirect(to: Routes.authentication_provider_path(conn, :request, "local", params))
      end
    else
      _ ->
        # if user does not exist still forward to local login
        conn
        |> redirect(to: Routes.authentication_provider_path(conn, :request, "local", params))
    end
  end

  def render_login(%Plug.Conn{} = conn) do
    conn
    |> render("login.html",
      callback_url: Routes.authentication_session_path(conn, :login),
      on_success: on_success(conn)
    )
  end

  def show(%Plug.Conn{assigns: %{session: session}} = conn, _params) do
    with session <- Repo.preload(session, :user) do
      conn
      |> render("show.html",
        logout_url: Routes.authentication_session_path(conn, :logout),
        username: session.user.username
      )
    end
  end

  def show(%Plug.Conn{} = conn, _params) do
    conn
    |> redirect(to: Routes.authentication_session_path(conn, :login))
  end

  def logout(%Plug.Conn{} = conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: on_success(conn))
  end

  # Helper to figure out where user should be redirected on succesfull authentication
  defp on_success(%Plug.Conn{} = conn) do
    Map.get(conn.params, "on_success", Routes.authentication_session_path(conn, :show))
  end

  @doc """
  Create a session, put it in browser session and redirect to the `on_success` param.

  This is usually the last authentication step.
  """
  def create_session(%Plug.Conn{} = conn, %User{} = user) do
    with {:ok, session} <- Session.create(user) do
      conn
      |> put_session(:session_id, session.id)
      |> redirect(to: on_success(conn))
    end
  end
end
