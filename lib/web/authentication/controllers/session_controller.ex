defmodule CPub.Web.Authentication.SessionController do
  @moduledoc """
  Handles session creation and deletion (login/logout).
  """

  use CPub.Web, :controller

  alias CPub.{Repo, User}

  alias CPub.Web.Authentication.{Registration, Session}

  action_fallback CPub.Web.FallbackController

  # Store a note in the session on where the user should be redirect when authentication succeeds.
  defp store_authentication_cb(conn) do
    if is_nil(get_session(conn, :authentication_cb)) do
      conn
      |> put_session(
        :authentication_cb,
        Map.get(conn.params, "on_success", Routes.authentication_session_path(conn, :show))
      )
    else
      conn
    end
  end

  # Redirect to authentication "on success" calback
  defp authentication_success(conn) do
    cb =
      get_session(conn, :authentication_cb) ||
        Map.get(conn.params, "on_success", Routes.authentication_session_path(conn, :show))

    conn
    |> delete_session(:authentication_cb)
    |> redirect(to: cb)
  end

  def login(%Plug.Conn{assigns: %{session: _session}} = conn, _params) do
    conn
    |> authentication_success()
  end

  def login(%Plug.Conn{method: "GET"} = conn, %{"error" => error_msg}) do
    conn
    |> put_flash(:error, error_msg)
    |> render_login()
  end

  def login(%Plug.Conn{method: "GET"} = conn, _params) do
    conn
    |> store_authentication_cb()
    |> render_login()
  end

  @doc """
  Try and figure out if credential is a username, a Fediverse server or an other useable identifier and dispatch the proper provider.
  """
  def login(%Plug.Conn{method: "POST"} = conn, %{"credential" => credential}) do
    uri = URI.parse(credential)

    if uri.scheme == "https" do
      conn
      |> login(%{site: credential})
    else
      conn
      |> login(%{username: credential})
    end
  end

  def login(%Plug.Conn{method: "POST"} = conn, %{username: username}) do
    with {:ok, user} <- Repo.get_one_by(User, %{username: username}),
         user <- user |> Repo.preload(:registration) do
      case user.registration do
        %Registration{provider: "fediverse"} ->
          conn
          |> redirect(
            to:
              Routes.authentication_provider_path(conn, :request, "fediverse", %{
                site: user.registration.site
              })
          )

        %Registration{provider: provider} ->
          conn
          |> redirect(to: Routes.authentication_provider_path(conn, :request, provider))

        nil ->
          conn
          |> redirect(
            to:
              Routes.authentication_provider_path(conn, :request, "local", %{username: username})
          )
      end
    else
      _ ->
        # if user does not exist still forward to local login
        conn
        |> redirect(
          to: Routes.authentication_provider_path(conn, :request, "local", %{username: username})
        )
    end
  end

  def login(%Plug.Conn{method: "POST"} = conn, %{site: site}) do
    conn
    |> redirect(
      to:
        Routes.authentication_provider_path(conn, :request, "fediverse", %{
          site: site
        })
    )
  end

  def render_login(%Plug.Conn{} = conn) do
    conn
    |> render("login.html",
      callback_url: Routes.authentication_session_path(conn, :login)
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
    |> authentication_success()
  end

  @doc """
  Create a session, put it in browser session and redirect to the `on_success` param.

  This is usually the last authentication step.
  """
  def create_session(%Plug.Conn{} = conn, %User{} = user) do
    with {:ok, session} <- Session.create(user) do
      conn
      |> put_session(:session_id, session.id)
      |> authentication_success()
    end
  end
end
