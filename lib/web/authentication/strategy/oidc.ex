# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.Strategy.OIDC do
  @moduledoc """
  Meta strategy for `Ueberauth.Strategy.OIDC` that allows dynamic client
  configuration.

  This invokes `OIDC.Provider` strategies for individual sites (providers in
  OIDC lingo).
  """

  use Ueberauth.Strategy

  alias CPub.Web.Authentication.OAuthClient
  alias CPub.Web.Authentication.Strategy.OIDC

  @spec handle_request!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_request!(%Plug.Conn{} = conn) do
    site = conn.params["site"]

    if is_nil(site) do
      set_errors!(conn, error("oidc", "no OpenID provider specified"))
    else
      # encode the site in the OAuth 2.0 state parameter
      state = Phoenix.Token.encrypt(conn, "ueberauth.oidc", site)

      case OAuthClient.get(site) do
        {:ok, client} ->
          Ueberauth.run_request(
            conn,
            strategy_name(conn),
            {OIDC.Provider,
             [
               provider: site,
               client_id: client.client_id,
               client_secret: client.client_secret,
               extra_request_params: %{state: state}
             ]}
          )

        _ ->
          set_errors!(conn, error("oidc", "no associated client"))
      end
    end
  end

  @spec handle_callback!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_callback!(%Plug.Conn{} = conn) do
    # extract the site from the state param
    with {:ok, site} <-
           Phoenix.Token.decrypt(conn, "ueberauth.oidc", conn.params["state"]),
         {:ok, client} <- OAuthClient.get(site) do
      Ueberauth.run_callback(
        conn,
        strategy_name(conn),
        {OIDC.Provider,
         [
           provider: site,
           client_id: client.client_id,
           client_secret: client.client_secret
         ]}
      )
      # act like we are not the OIDC strategy
      |> replace_strategy()
    end
  end

  @spec replace_strategy(Plug.Conn.t()) :: Plug.Conn.t()
  defp replace_strategy(%Plug.Conn{assigns: %{ueberauth_auth: auth}} = conn) do
    assign(conn, :ueberauth_auth, %{auth | strategy: __MODULE__})
  end

  defp replace_strategy(conn), do: conn
end
