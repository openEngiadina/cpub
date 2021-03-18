# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.ProviderController do
  @moduledoc """
  Implements interactive user authentication by means of different providers.

  If authentication is successfull a `CPub.Web.Authentication.Session` will be stored in the `Plug.Session`.
  """
  use CPub.Web, :controller

  alias CPub.User

  alias CPub.Web.Authentication.RegistrationRequest
  alias CPub.Web.Authentication.Strategy

  alias CPub.Web.Authentication.SessionController

  alias Ueberauth.Strategy.Helpers

  alias Phoenix.Token

  action_fallback CPub.Web.FallbackController

  plug Ueberauth, provider: [:internal]

  def request(%Plug.Conn{} = conn, %{"provider" => "internal"}) do
    conn
    |> render("internal.html",
      callback_url: Helpers.callback_path(conn),
      username: conn.params["username"]
    )
  end

  def request(%Plug.Conn{assigns: %{ueberauth_failure: _fails}}, %{"provider" => provider}) do
    {:error, "Failed to run request for provider #{provider}"}
  end

  # go back to session login on failure
  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> redirect(
      to: Routes.authentication_session_path(conn, :login, error: "Failed to authenticate.")
    )
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case auth.strategy do
      Strategy.Internal ->
        conn
        |> SessionController.create_session(auth.extra.raw_info.user)

      Strategy.Mastodon ->
        site = auth.extra.raw_info.site
        username = auth.extra.raw_info.account["username"] || auth.uid

        conn
        |> callback_external_provider(site, :mastodon, auth.uid, username)

      Strategy.OIDC ->
        # site is called provider in OpenID lingo
        site = auth.extra.raw_info.provider
        username = auth.extra.raw_info.id_token["preferred_username"] || auth.uid

        conn
        |> callback_external_provider(site, :oidc, auth.uid, username)
    end
  end

  def callback_external_provider(conn, site, provider, external_id, username) do
    # If user is already registered create a session an succeed
    case User.Registration.get_external(site, provider, external_id) do
      {:ok, registration} ->
        with {:ok, user} <- User.get_by_id(registration.user) do
          conn
          |> SessionController.create_session(user)
        end

      # if not create a registration requeset and redirect user to register form
      _ ->
        with {:ok, registration_request} <-
               RegistrationRequest.create(site, provider, external_id, username),
             registration_token <-
               Token.sign(conn, "registration_request", registration_request.id) do
          conn
          |> redirect(
            to:
              Routes.authentication_registration_path(conn, :register, request: registration_token)
          )
        end
    end
  end
end
