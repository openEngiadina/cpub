# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.Strategy.Mastodon do
  @moduledoc """
  `Ueberauth.Strategy` for authenticating with a dynamic Mastodon/Pleroma
  instance.

  This is a "meta"-Strategy and uses
  `CPub.Web.Authentication.Strategy.Mastodon.Instance` for authenticating with
  individual instances.
  """

  use Ueberauth.Strategy

  alias CPub.HTTP
  alias CPub.Web.Authentication.OAuthClient
  alias CPub.Web.Authentication.Strategy.Mastodon.Instance

  # The Mastodon API for dynamically creating clients
  # (see https://docs.joinmastodon.org/methods/apps/)
  @register_client_endpoint "/api/v1/apps"

  # TODO this should idenitfy the instance
  @default_client_name "CPub"

  @spec handle_request!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_request!(%Plug.Conn{} = conn) do
    site = conn.params["site"]

    if is_nil(site) do
      set_errors!(conn, error("mastodon_no_site_given", "no site given"))
    else
      # encode the site in the OAuth 2.0 state parameter
      state = Phoenix.Token.encrypt(conn, "ueberauth.mastodon", site)

      case get_client(conn, site) do
        {:ok, client} ->
          Ueberauth.run_request(
            conn,
            strategy_name(conn),
            {Instance,
             [
               site: site,
               client_id: client.client_id,
               client_secret: client.client_secret,
               oauth_request_params: %{state: state, scope: "read:accounts"}
             ]}
          )

        _ ->
          set_errors!(conn, error("mastodon_no_client", "failed to create client"))
      end
    end
  end

  # Get or create a suitable client for the site.
  @spec get_client(Plug.Conn.t(), URI.t() | String.t()) ::
          {:ok, OAuthClient.t()} | {:error, any}
  defp get_client(%Plug.Conn{} = conn, site) do
    case OAuthClient.get(site) do
      {:ok, client} ->
        {:ok, client}

      _ ->
        create_client(conn, site)
    end
  end

  # Create a client by using the apps endpoint
  @spec create_client(Plug.Conn.t(), URI.t() | String.t()) ::
          {:ok, OAuthClient.t()} | {:error, any}
  defp create_client(%Plug.Conn{} = conn, site) do
    url =
      site
      |> URI.merge(@register_client_endpoint)
      |> URI.to_string()

    headers = [{"Content-Type", "application/json"}]

    body =
      Jason.encode!(%{
        client_name: @default_client_name,
        scopes: "read:accounts",
        redirect_uris: callback_url(conn)
      })

    with {:ok, %{body: body}} <- HTTP.post(url, body, headers, []),
         {:ok, client_attrs} <- Jason.decode(body) do
      OAuthClient.create(%{
        site: site,
        provider: :mastodon,
        client_id: client_attrs["client_id"],
        client_secret: client_attrs["client_secret"]
      })
    end
  end

  @spec handle_callback!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_callback!(%Plug.Conn{} = conn) do
    # extract the site from the state param
    with {:ok, site} <-
           Phoenix.Token.decrypt(conn, "ueberauth.mastodon", conn.params["state"]),
         {:ok, client} <- get_client(conn, site) do
      Ueberauth.run_callback(
        conn,
        strategy_name(conn),
        {Instance,
         [
           site: site,
           client_id: client.client_id,
           client_secret: client.client_secret,
           oauth_request_params: %{}
         ]}
      )
      # act like we are not the Pleroma strategy
      |> replace_strategy()
    end
  end

  @spec replace_strategy(Plug.Conn.t()) :: Plug.Conn.t()
  defp replace_strategy(%Plug.Conn{assigns: %{ueberauth_auth: auth}} = conn) do
    assign(conn, :ueberauth_auth, %{auth | strategy: __MODULE__})
  end

  defp replace_strategy(conn), do: conn
end
