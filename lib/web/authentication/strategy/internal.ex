# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.Strategy.Internal do
  @moduledoc """
  `Ueberauth.Strategy` for authentication with username/password (using the
  internal database).
  """

  use Ueberauth.Strategy

  alias CPub.User

  alias Ueberauth.Auth.Extra

  @spec uid(Plug.Conn.t()) :: String.t()
  def uid(%Plug.Conn{private: %{user: %User{id: user_id}}}), do: user_id

  @spec extra(Plug.Conn.t()) :: Extra.t()
  def extra(%Plug.Conn{private: %{user: %User{} = user}}), do: %Extra{raw_info: %{user: user}}

  @spec handle_callback!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_callback!(%Plug.Conn{} = conn) do
    username = conn.params["username"]
    password = conn.params["password"]

    with {:ok, user} <- User.get(username),
         {:ok, %User.Registration{provider: :internal} = registration} <-
           User.Registration.get_user_registration(user),
         :ok <- User.Registration.check_internal(registration, password) do
      put_private(conn, :user, user)
    else
      :invalid_password ->
        set_errors!(conn, [error("invalid_username_password", "Invalid username or password.")])

      _ ->
        # Compute a Argon hash to prevent timing attacks
        Argon2.no_user_verify()

        set_errors!(conn, [error("invalid_username_password", "Invalid username or password.")])
    end
  end
end
