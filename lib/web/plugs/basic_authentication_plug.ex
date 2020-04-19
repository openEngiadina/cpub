defmodule CPub.Web.BasicAuthenticationPlug do
  @moduledoc """
  Plug for authentication.

  If user is correctly authenticated the user is assigned to the connection. If
  not the connection is just passed trough.
  """

  import Plug.Conn

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(conn, _opts) do
    with ["Basic " <> encoded] <- Plug.Conn.get_req_header(conn, "authorization"),
         {:ok, credentials} <- Base.decode64(encoded),
         [username, password] <- String.split(credentials, ":", parts: 2),
         # Verify username and password and assign user to connection
         {:ok, user} <- CPub.User.verify_password(username, password) do
      assign(conn, :user, user)
    else
      _ ->
        unauthorise(conn)
    end
  end

  @doc """
  If not authorized, just don't assign the user.
  """
  @spec unauthorise(Plug.Conn.t()) :: Plug.Conn.t()
  def unauthorise(conn), do: conn
end
