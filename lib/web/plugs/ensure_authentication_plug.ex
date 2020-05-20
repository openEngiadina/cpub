defmodule CPub.Web.EnsureAuthenticationPlug do
  @moduledoc """
  Plug to ensure that connections is authenticated with a `CPub.User`.
  """

  import Plug.Conn

  alias CPub.User

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(%Plug.Conn{assigns: %{user: %User{}}} = conn, _opts), do: conn
  def call(%Plug.Conn{} = conn, _opts), do: unauthorized(conn)

  @spec unauthorized(Plug.Conn.t()) :: Plug.Conn.t()
  def unauthorized(%Plug.Conn{} = conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(:unauthorized, "401 Unauthorized")
    |> halt()
  end
end
