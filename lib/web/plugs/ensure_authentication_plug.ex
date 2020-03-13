defmodule CPub.Web.EnsureAuthenticationPlug do
  @moduledoc """
  Plug to ensure that connections is authenticated with a `CPub.User`.
  """

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
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(401, "401 Unauthorized")
    |> Plug.Conn.halt()
  end
end
