# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.Strategy.OIDC.Provider do
  @moduledoc """
  An Ueberauth strategy for identifying with services implementing [OpenID
  Connect](https://openid.net/specs/openid-connect-core-1_0.html).

  # Configuration

  ````
  {Ueberauth.Strategy.OIDC, [
    provider: "https://your-favorite-openid-provider.com/",
    client_id: "blups",
    client_secret: "blupsblipsblabla"
  ]}
  ````

  There is no need to specify the authorization, token and jwk endpoint. The strategy will automatically detect them from the [OpenID Provider Configuration Information](https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderConfig).


  TODO: Currently this strategy make multiple requests to the OpenID provider every time it is invoked that could be cached (configuration and jwks keys). Implement a more efficient caching strategy.
  """

  use Ueberauth.Strategy

  alias Ueberauth.Auth.{Credentials, Extra}

  # helpers for accessing configuration
  defp provider(conn), do: Keyword.get(options(conn), :provider)
  defp client_id(conn), do: Keyword.get(options(conn), :client_id)
  defp client_secret(conn), do: Keyword.get(options(conn), :client_secret)
  defp extra_request_params(conn), do: Keyword.get(options(conn), :extra_request_params, %{})

  defp authorization_endpoint(config), do: config["authorization_endpoint"]
  defp token_endpoint(config), do: config["token_endpoint"]
  defp jwks_uri(config), do: config["jwks_uri"]

  # always add the openid scope
  defp scope(conn) do
    (Keyword.get(options(conn), :scope, []) ++ ["openid"])
    |> MapSet.new()
    |> Enum.join(" ")
  end

  @openid_configuration_endpoint ".well-known/openid-configuration"

  # Get configuration from OpenID configuration path
  defp get_openid_config(conn) do
    uri =
      (provider(conn) <> "/")
      |> URI.merge(@openid_configuration_endpoint)
      |> URI.to_string()

    headers = [{"Content-Type", "application/json"}]

    with {:ok, _, _, client_ref} <-
           :hackney.request(:get, uri, headers, <<>>, []),
         {:ok, body_binary} <- :hackney.body(client_ref),
         {:ok, body} <- Jason.decode(body_binary) do
      {:ok, body}
    else
      _ ->
        {:error, "could not get OpenID configuration"}
    end
  end

  defp oauth_client(conn, config) do
    [
      authorize_url: authorization_endpoint(config),
      token_url: token_endpoint(config),
      client_id: client_id(conn),
      client_secret: client_secret(conn),
      params: Map.merge(extra_request_params(conn), %{scope: scope(conn)}),
      redirect_uri: callback_url(conn),
      strategy: CPub.Web.Authentication.Strategy.OIDC.OAuth2.Strategy.PublicAuthCode
    ]
    |> OAuth2.Client.new()
    |> OAuth2.Client.put_serializer("application/json", Jason)
  end

  def handle_request!(%Plug.Conn{} = conn) do
    with {:ok, config} <- get_openid_config(conn),
         client <- oauth_client(conn, config) do
      conn
      |> redirect!(OAuth2.Client.authorize_url!(client))
    else
      {:error, err} ->
        conn
        |> set_errors!([error("oidc", err)])
    end
  end

  # the subject identifier from the id_token is guaranteed to be a locally unique identifier
  def uid(conn), do: conn.private.ueberauth_oidc_id_token["sub"]

  def extra(conn) do
    %Extra{
      raw_info: %{
        provider: provider(conn),
        id_token: conn.private.ueberauth_oidc_id_token,
        token: conn.private.ueberauth_oidc_oauth_client.token
      }
    }
  end

  def credentials(conn) do
    client = conn.private.ueberauth_oidc_oauth_client

    %Credentials{
      expires: OAuth2.AccessToken.expires?(client.token),
      expires_at: client.token.expires_at,
      token: client.token.access_token,
      refresh_token: client.token.refresh_token,
      token_type: client.token.token_type
    }
  end

  def handle_callback!(%Plug.Conn{} = conn) do
    with {:ok, config} <- get_openid_config(conn),
         client <- oauth_client(conn, config),
         {:ok, client} <- OAuth2.Client.get_token(client, code: conn.params["code"]),
         {:ok, id_token} <- verify_id_token(config, client) do
      conn
      |> put_private(:ueberauth_oidc_oauth_client, client)
      |> put_private(:ueberauth_oidc_id_token, id_token)
    else
      _ ->
        conn
        |> set_errors!([error("oidc", "could not get access token")])
    end
  rescue
    _ ->
      conn
      |> set_errors!([error("oidc", "could not get access token")])
  end

  # parse a Joken.Signer from the keys at the jwks endpoint
  defp parse_signer(key) do
    # the alg key is optional (!?!) default to RSA256 if none provided. This is not nice, but seems to be what other projects do as well (https://github.com/spring-projects/spring-security-oauth/issues/1097)
    {:ok, Joken.Signer.create(key["alg"] || "RS256", key)}
  rescue
    err ->
      {:error, err}
  end

  # fetch keys from jwks_uri endpoint and return matching key as Jose.Signer
  defp get_signer(config, kid) do
    headers = [{"Content-Type", "application/json"}]

    with {:ok, _, _, client_ref} <-
           :hackney.request(:get, jwks_uri(config), headers, <<>>, []),
         {:ok, body_binary} <- :hackney.body(client_ref),
         {:ok, body} <- Jason.decode(body_binary),
         keys <- body["keys"] do
      case Enum.find(keys, fn key -> key["kid"] == kid end) do
        nil ->
          {:error, "no matching key found at jwks_uri"}

        key ->
          parse_signer(key)
      end
    end
  end

  # verify the id_token
  defp verify_id_token(config, client) do
    with jwt <- client.token.other_params["id_token"],
         {:ok, headers} <- Joken.peek_header(jwt),
         {:ok, signer} <- get_signer(config, headers["kid"]) do
      Joken.verify(jwt, signer)
    end
  end
end
