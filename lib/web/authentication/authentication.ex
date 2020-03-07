defmodule CPub.Web.Authentication do
  @moduledoc """
  Plug for authentication.

  If user is correctly authenticated the user is assigned to the connection. If
  not the connection is just passed trough.
  """

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    header_content = Plug.Conn.get_req_header(conn, "authorization")
    respond(conn, header_content)
  end

  def respond(conn, ["Basic " <> encoded]) do
    case Base.decode64(encoded) do
      {:ok, token} ->
        check_token(conn, token)

      _ ->
        unauthorise(conn)
    end
  end

  def respond(conn, _) do
    unauthorise(conn)
  end

  defp check_token(conn, token) do
    case String.split(token, ":", parts: 2) do
      [username, password] ->
        conn
        |> verify_user(username, password)

      _ ->
        unauthorise(conn)
    end
  end

  @doc """
  Verify username and password and assign user to connection or halt connection.
  """
  def verify_user(conn, username, password) do
    case CPub.User.verify_user(username, password) do
      {:ok, user} ->
        Plug.Conn.assign(conn, :user, user)

      _ ->
        unauthorise(conn)
    end
  end

  @doc """
  If not authorized, just don't assign the user.
  """
  def unauthorise(conn) do
    conn
  end
end
