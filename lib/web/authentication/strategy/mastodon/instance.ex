# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.Strategy.Mastodon.Instance do
  @moduledoc """
  An Ueberauth strategy for Pleroma/Mastodon compatible providers.

  This Strategy requires a site, client_id and client_secret and is limited to a
  single Pleroma/Mastodon instance.
  """

  use Ueberauth.Strategy

  alias CPub.Web.Authentication.OAuthClient
  alias CPub.Web.Authentication.OAuthRequest
  alias CPub.Web.Authentication.Strategy.Mastodon

  alias Ueberauth.Auth.{Credentials, Extra, Info}

  @spec handle_request!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_request!(%Plug.Conn{} = conn) do
    client =
      Mastodon.OAuth.client(
        site: Keyword.get(options(conn), :site),
        client_id: Keyword.get(options(conn), :client_id),
        redirect_uri: callback_url(conn),
        params: Keyword.get(options(conn), :oauth_request_params)
      )

    redirect!(conn, OAuth2.Client.authorize_url!(client))
  end

  @spec handle_callback!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_callback!(%Plug.Conn{} = conn) do
    client =
      Mastodon.OAuth.client(
        site: Keyword.get(options(conn), :site),
        client_id: Keyword.get(options(conn), :client_id),
        client_secret: Keyword.get(options(conn), :client_secret),
        redirect_uri: callback_url(conn),
        params: Keyword.get(options(conn), :oauth_request_params)
      )

    opts = [code: conn.params["code"]]

    opts =
      if Keyword.get(options(conn), :client_secret),
        do: Keyword.put(opts, :client_secret, Keyword.get(options(conn), :client_secret)),
        else: opts

    case OAuthClient.get_token(client, opts) do
      {:ok, client} ->
        conn
        |> put_private(:ueberauth_pleroma_oauth_client, client)
        |> verify_account(client)

      {:error, _} ->
        set_errors!(conn, [error("pleroma", "failed to get access token")])
    end
  end

  # Fill in the Ueberauth.Auth struct

  @spec uid(Plug.Conn.t()) :: String.t()
  def uid(%Plug.Conn{} = conn), do: conn.private.ueberauth_pleroma_account["url"]

  @spec extra(Plug.Conn.t()) :: Extra.t()
  def extra(%Plug.Conn{} = conn) do
    %Extra{
      raw_info: %{
        account: conn.private.ueberauth_pleroma_account,
        token: conn.private.ueberauth_pleroma_oauth_client.token,
        site: Keyword.get(options(conn), :site)
      }
    }
  end

  @spec info(Plug.Conn.t()) :: Info.t()
  def info(%Plug.Conn{} = conn) do
    account = conn.private.ueberauth_pleroma_account

    %Info{nickname: account["username"]}
  end

  @spec credentials(Plug.Conn.t()) :: Credentials.t()
  def credentials(%Plug.Conn{} = conn) do
    client = conn.private.ueberauth_pleroma_oauth_client

    %Credentials{
      expires: OAuth2.AccessToken.expires?(client.token),
      expires_at: client.token.expires_at,
      token: client.token.access_token,
      refresh_token: client.token.refresh_token,
      token_type: client.token.token_type
    }
  end

  @verify_account_credentials_endpoint "/api/v1/accounts/verify_credentials"

  # gets additional information from the "verify account credentials" endpoint
  @spec verify_account(Plug.Conn.t(), OAuth2.Client.t()) :: Plug.Conn.t()
  defp verify_account(%Plug.Conn{} = conn, client) do
    case OAuthRequest.request(:get, client, @verify_account_credentials_endpoint, "", [], []) do
      {:ok, %OAuth2.Response{body: body}} ->
        put_private(conn, :ueberauth_pleroma_account, body)

      _ ->
        set_errors!(conn, [
          error("pleroma", "could not fetch account details from verify credential endpoint")
        ])
    end
  end
end
