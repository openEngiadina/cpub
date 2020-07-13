defmodule CPub.Web.Authentication.AuthenticationController do
  @moduledoc """
  Implements interactive user authentication.

  If authentication is successfull a `CPub.Web.Authentication.Session` will be stored in the `Plug.Session`.

  Note that the session can only be used to issue an authorization via OAuth, no access to ressources is granted with a session.
  """
  use CPub.Web, :controller

  alias CPub.User
  alias CPub.Web.Authentication.Session

  plug :fetch_session
  plug :fetch_flash

  @doc """
  Authenticate a user and set a session and redirect to `on_success`.
  """
  def login(%Plug.Conn{assigns: %{session: %Session{}}} = conn, %{"on_success" => on_success}) do
    conn
    |> redirect(to: on_success)
  end

  def login(%Plug.Conn{} = conn, %{
        "login_form" => %{
          "username" => username,
          "password" => password,
          "on_success" => on_success
        }
      }) do
    case User.get_by_password(username, password) do
      {:ok, user} ->
        with {:ok, session} <- Session.create(user) do
          conn
          |> put_session(:session_id, session.id)
          |> redirect(to: on_success)
        end

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid credentials.")
        |> put_status(:unauthorized)
        |> login(%{"on_success" => on_success})
    end
  end

  def login(%Plug.Conn{} = conn, %{} = params) do
    on_success = Map.get(params, "on_success", "/")

    conn
    |> render("login.html", %{
      on_success: on_success
    })
  end

  def login(%Plug.Conn{} = conn, on_success: on_success) do
    conn
    |> redirect(
      to: Routes.authentication_authentication_path(conn, :login, %{"on_success" => on_success})
    )
  end
end
