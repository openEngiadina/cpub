defmodule CPub.Web.Authentication.Strategy.Internal do
  @moduledoc """
  `Ueberauth.Strategy` for authentication with username/password (using the
  internal database).
  """
  use Ueberauth.Strategy

  alias CPub.User

  alias Ueberauth.Auth.Extra

  def uid(conn), do: conn.private.user.id

  def extra(conn), do: %Extra{raw_info: %{user: conn.private.user}}

  def handle_callback!(conn) do
    username = conn.params["username"]
    password = conn.params["password"]

    with {:ok, user} <- User.get(username),
         {:ok, %User.Registration{type: :internal} = registration} <-
           User.Registration.get_user_registration(user),
         :ok <- User.Registration.check_internal(registration, password) do
      conn
      |> put_private(:user, user)
    else
      :invalid_password ->
        conn
        |> set_errors!([error("invalid_username_password", "invalid username or password")])

      _ ->
        # Compute a Argon hash to prevent timing attacks
        Argon2.no_user_verify()

        conn
        |> set_errors!([error("invalid_username_password", "invalid username or password")])
    end
  end
end
