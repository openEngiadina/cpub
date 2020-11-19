defmodule CPub.Web.Authentication.SessionController do
  @moduledoc """
  Handles session creation and deletion (login/logout).
  """

  use CPub.Web, :controller

  alias CPub.User

  alias CPub.{Repo, User}

  alias CPub.Web.Authentication.{OAuthClient, Registration, Session}

  action_fallback CPub.Web.FallbackController

  # Store a note in the session on where the user should be redirect when authentication succeeds.
  defp store_authentication_cb(conn) do
    cb =
      conn.params["on_success"] ||
        get_session(conn, :authentication_cb) ||
        Routes.authentication_session_path(conn, :show)

    conn
    |> put_session(:authentication_cb, cb)
  end

  # Redirect to authentication "on success" calback
  defp authentication_success(conn) do
    cb = get_session(conn, :authentication_cb) || Routes.authentication_session_path(conn, :show)

    conn
    |> delete_session(:authentication_cb)
    |> redirect(to: cb)
  end

  def login(%Plug.Conn{assigns: %{session: _session}} = conn, _params) do
    conn
    |> store_authentication_cb()
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
    with {:ok, user} <- User.get(username),
         {:ok, registration} <- User.Registration.get_user_registration(user) do
      case registration.type do
        :internal ->
          conn
          |> redirect(
            to:
              Routes.authentication_provider_path(conn, :request, "internal", %{
                username: username
              })
          )

        :oidc ->
          conn
          |> redirect(
            to:
              Routes.authentication_provider_path(conn, :request, "oidc", %{
                site: user.registration.site
              })
          )

        :mastodon ->
          conn
          |> redirect(
            to:
              Routes.authentication_provider_path(conn, :request, "mastodon", %{
                site: user.registration.site
              })
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
        Routes.authentication_provider_path(conn, :request, "mastodon", %{
          site: site
        })
    )
  end

  def render_login(%Plug.Conn{} = conn) do
    with {:ok, clients} <- OAuthClient.get_displayable() do
      conn
      |> render("login.html",
        callback_url: Routes.authentication_session_path(conn, :login),
        clients: clients
      )
    end
  end

  def show(%Plug.Conn{assigns: %{session: session}} = conn, _params) do
    with {:ok, user} <- User.get_by_id(session.user) do
      conn
      |> render("show.html",
        logout_url: Routes.authentication_session_path(conn, :logout),
        username: user.username
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
