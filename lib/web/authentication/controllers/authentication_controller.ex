defmodule CPub.Web.Authentication.AuthenticationController do
  @moduledoc """
  Implements interactive user authentication.

  If authentication is successfull a `CPub.Web.Authentication.Session` will be stored in the `Plug.Session`.

  Note that the session can only be used to issue an authorization via OAuth, no access to ressources is granted with a session.
  """
  use CPub.Web, :controller

  alias CPub.Web.Authentication.Registration
  alias CPub.Web.Authentication.Session
  alias CPub.Web.Authentication.Strategy

  alias Ueberauth.Strategy.Helpers

  plug Ueberauth, provider: [:local]

  # TODO set to something nice
  @default_on_success "/auth/local"

  def on_success(%Plug.Conn{} = conn) do
    Map.get(conn.params, "on_success", @default_on_success)
  end

  def request(%Plug.Conn{assigns: %{session: session}} = conn, _params) do
    conn
    |> put_flash(:info, "Already authenticated.")
    |> render_login()
  end

  def request(%Plug.Conn{} = conn, _params) do
    conn
    |> render_login()
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> put_status(:unauthorized)
    |> render_login()
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    auth |> IO.inspect()

    case auth.strategy do
      Strategy.Local ->
        with {:ok, session} <- Session.create(auth.extra.raw_info.user) do
          conn
          |> put_session(:session_id, session.id)
          |> redirect(to: on_success(conn))
        end

      Ueberauth.Strategy.Pleroma ->
        with {:ok, registration} <- Registration.get_from_auth(auth),
             {:ok, session} <- Session.create(registration.user) do
          conn
          |> put_session(:session_id, session.id)
          |> redirect(to: on_success(conn))
        else
          _ ->
            conn
            |> put_flash(:error, "You are not registered.")
            |> render_login()
        end
    end
  end

  @doc """
  Authenticate a user and set a session and redirect to `on_success`.
  """

  # def login(%Plug.Conn{assigns: %{session: %Session{}}} = conn, params) do
  #   on_success = Map.get(params, "on_success", @default_on_success)

  #   conn
  #   |> redirect(to: on_success)
  # end

  defp render_login(%Plug.Conn{} = conn) do
    conn
    |> render("login.html",
      callback_url: Helpers.callback_path(conn),
      on_success: on_success(conn)
    )
  end
end
