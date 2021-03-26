# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.ProviderController do
  @moduledoc """
  Implements interactive user authentication by means of different providers.

  If authentication is successfull a `CPub.Web.Authentication.Session` will be
  stored in the `Plug.Session`.
  """

  use CPub.Web, :controller

  alias CPub.User

  alias CPub.Web.Authentication.RegistrationRequest
  alias CPub.Web.Authentication.SessionController
  alias CPub.Web.Authentication.Strategy

  alias Phoenix.Token

  alias Ueberauth.Strategy.Helpers

  action_fallback CPub.Web.FallbackController

  plug Ueberauth, provider: [:internal]

  @spec request(Plug.Conn.t(), map) :: Plug.Conn.t() | {:error, any}
  def request(%Plug.Conn{} = conn, %{"provider" => "internal"}) do
    render(conn, "internal.html",
      callback_url: Helpers.callback_path(conn),
      username: conn.params["username"]
    )
  end

  def request(
        %Plug.Conn{assigns: %{ueberauth_failure: _fails}} = conn,
        %{"provider" => provider}
      ) do
    error = "Failed to run request for provider #{provider}"
    path = Routes.authentication_session_path(conn, :login, error: error)

    redirect(conn, to: path)
  end

  @spec callback(Plug.Conn.t(), map) :: Plug.Conn.t()
  def callback(%Plug.Conn{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    # go back to session login on failure
    path = Routes.authentication_session_path(conn, :login, error: "Failed to authenticate.")

    redirect(conn, to: path)
  end

  def callback(%Plug.Conn{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case auth.strategy do
      Strategy.Internal ->
        SessionController.create_session(conn, auth.extra.raw_info.user)

      Strategy.Mastodon ->
        site = auth.extra.raw_info.site
        username = auth.extra.raw_info.account["username"] || auth.uid

        callback_external_provider(conn, site, :mastodon, auth.uid, username)

      Strategy.OIDC ->
        # site is called provider in OpenID lingo
        site = auth.extra.raw_info.provider
        username = auth.extra.raw_info.id_token["preferred_username"] || auth.uid

        callback_external_provider(conn, site, :oidc, auth.uid, username)
    end
  end

  @spec callback_external_provider(Plug.Conn.t(), String.t(), atom, String.t(), String.t()) ::
          Plug.Conn.t()
  def callback_external_provider(conn, site, provider, external_id, username) do
    # If user is already registered create a session an succeed
    case User.Registration.get_external(site, provider, external_id) do
      {:ok, registration} ->
        with {:ok, user} <- User.get_by_id(registration.user),
             do: SessionController.create_session(conn, user)

      # if not create a registration requeset and redirect user to register form
      _ ->
        with {:ok, registration_request} <-
               RegistrationRequest.create(site, provider, external_id, username),
             registration_token <-
               Token.sign(conn, "registration_request", registration_request.id) do
          path =
            Routes.authentication_registration_path(conn, :register, request: registration_token)

          redirect(conn, to: path)
        end
    end
  end
end
