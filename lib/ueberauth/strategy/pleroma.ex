defmodule Ueberauth.Strategy.Pleroma do
  @moduledoc """
  An Ueberauth strategy for Pleroma/Mastodon compatible providers.

  This Strategy requires a site, client_id and client_secret and is limited to a single Pleroma/Mastodon instance.
  """

  use Ueberauth.Strategy

  alias Ueberauth.Auth.{Credentials, Extra, Info}

  def handle_request!(%Plug.Conn{} = conn) do
    client =
      __MODULE__.OAuth.client(
        site: Keyword.get(options(conn), :site),
        client_id: Keyword.get(options(conn), :client_id),
        redirect_uri: callback_url(conn),
        params: client_params(conn)
      )

    conn
    |> redirect!(OAuth2.Client.authorize_url!(client))
  end

  def handle_callback!(%Plug.Conn{} = conn) do
    client =
      __MODULE__.OAuth.client(
        site: Keyword.get(options(conn), :site),
        client_id: Keyword.get(options(conn), :client_id),
        client_secret: Keyword.get(options(conn), :client_secret),
        redirect_uri: callback_url(conn),
        params: client_params(conn)
      )

    opts = [code: conn.params["code"]]

    opts =
      if Keyword.get(options(conn), :client_secret),
        do: Keyword.put(opts, :client_secret, Keyword.get(options(conn), :client_secret)),
        else: opts

    case OAuth2.Client.get_token(client, opts) do
      {:ok, client} ->
        conn
        |> put_private(:ueberauth_pleroma_oauth_client, client)
        |> verify_account(client)

      {:error, _} ->
        conn
        |> set_errors!([error("pleroma", "failed to get access token")])
    end
  end

  # Fill in the Ueberauth.Auth struct

  def uid(conn), do: conn.private.ueberauth_pleroma_account["url"]

  def extra(conn) do
    %Extra{
      raw_info: %{
        account: conn.private.ueberauth_pleroma_account,
        token: conn.private.ueberauth_pleroma_oauth_client.token,
        site: Keyword.get(options(conn), :site)
      }
    }
  end

  def info(conn) do
    account = conn.private.ueberauth_pleroma_account

    %Info{
      nickname: account["username"]
    }
  end

  def credentials(conn) do
    client = conn.private.ueberauth_pleroma_oauth_client

    %Credentials{
      expires: OAuth2.AccessToken.expires?(client.token),
      expires_at: client.token.expires_at,
      token: client.token.access_token,
      refresh_token: client.token.refresh_token,
      token_type: client.token.token_type
    }
  end

  # Helper that add optional state and scope
  defp client_params(conn) do
    client_params = %{}

    client_params =
      if conn.params["state"],
        do: Map.put(client_params, :state, conn.params["state"]),
        else: client_params

    client_params =
      if conn.params["scope"],
        do: Map.put(client_params, :scope, conn.params["scope"]),
        else: client_params

    client_params
  end

  @verify_account_credentials_endpoint "/api/v1/accounts/verify_credentials"

  # gets additional information from the "verify account credentials" endpoint
  defp verify_account(conn, client) do
    case OAuth2.Client.get(client, @verify_account_credentials_endpoint) do
      {:ok, %OAuth2.Response{body: body}} ->
        conn
        |> put_private(:ueberauth_pleroma_account, body)

      _ ->
        conn
        |> set_errors!([
          error("pleroma", "could not fetch account details from verify credential endpoint")
        ])
    end
  end
end
