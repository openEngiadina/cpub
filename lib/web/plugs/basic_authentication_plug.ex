defmodule CPub.Web.BasicAuthenticationPlug do
  @moduledoc """
  Plug for basic authentication.

  If user is correctly authenticated the user is assigned to the connection.
  If not the connection is just passed trough.
  """

  import Plug.Conn

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(%Plug.Conn{} = conn, _opts) do
    with {username, password} <- fetch_credentials(conn),
         # Verify username and password and assign user to connection
         {:ok, user} <- CPub.User.get_by_password(username, password) do
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
  def unauthorise(%Plug.Conn{} = conn), do: conn

  @spec fetch_credentials(Plug.Conn.t()) :: {String.t(), String.t()} | nil
  def fetch_credentials(%Plug.Conn{} = conn) do
    with ["Basic " <> encoded] <- Plug.Conn.get_req_header(conn, "authorization"),
         {:ok, credentials} <- Base.decode64(encoded),
         [username, password] <-
           Enum.map(String.split(credentials, ":", parts: 2), &URI.decode_www_form(&1)) do
      {username, password}
    else
      _ ->
        nil
    end
  end
end
