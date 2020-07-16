defmodule CPub.Web.Authentication.SessionController do
  @moduledoc """
  Handles session creation and deletion (login/logout).
  """

  use CPub.Web, :controller

  alias CPub.Repo
  alias CPub.User
  alias CPub.Web.Authentication.Session

  action_fallback CPub.Web.FallbackController

  # TODO set to something nice
  @default_on_success "/auth/local"

  def on_success(%Plug.Conn{} = conn) do
    Map.get(conn.params, "on_success", @default_on_success)
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
