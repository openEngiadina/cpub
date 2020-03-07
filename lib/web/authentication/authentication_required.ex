defmodule CPub.Web.Authentication.Required do
  @moduledoc """
  Plug to ensure that connections is authenticated with a `CPub.User`.
  """

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    case conn.assigns[:user] do
      %CPub.User{} ->
        conn

      _ ->
        unauthorized(conn)
    end
  end

  def unauthorized(conn) do
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(401, "401 Unauthorized")
    |> Plug.Conn.halt()
  end
end
