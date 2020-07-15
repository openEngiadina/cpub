defmodule CPub.Web.Authentication.Strategy.Local do
  @moduledoc """
  `Ueberauth.Strategy` for local authentication with username/password.
  """
  use Ueberauth.Strategy

  alias CPub.User

  alias Ueberauth.Auth.Extra

  def uid(conn), do: conn.private.user.id

  def extra(conn), do: %Extra{raw_info: %{user: conn.private.user}}

  def handle_callback!(conn) do
    username = conn.params["username"]
    password = conn.params["password"]

    IO.inspect("in local callback!")

    case User.get_by_password(username, password) do
      {:ok, user} ->
        conn
        |> put_private(:user, user)

      _ ->
        conn
        |> set_errors!([error("local", "invalid username/password")])
    end
  end
end
