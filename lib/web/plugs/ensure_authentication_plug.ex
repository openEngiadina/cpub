defmodule CPub.Web.EnsureAuthenticationPlug do
  @moduledoc """
  Plug to ensure that connections is authenticated with a `CPub.User`.
  """

  import Plug.Conn

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case conn.assigns[:user] do
      %CPub.User{} ->
        conn

      _ ->
        unauthorized(conn)
    end
  end

  @spec unauthorized(Plug.Conn.t()) :: Plug.Conn.t()
  def unauthorized(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(401, "401 Unauthorized")
    |> halt()
  end
end
