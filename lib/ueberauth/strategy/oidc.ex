defmodule Ueberauth.Strategy.OIDC do
  @doc """
  An Ueberauth strategy for identifying with services implementing [OpenID Connect](https://openid.net/specs/openid-connect-core-1_0.html).

  TODO: Currently this strategy make multiple requests to the OpenID provider every time it is invoked that could be cached (configuration and jwks keys). Implement a more efficient caching strategy.
  """

  use Ueberauth.Strategy

  alias Ueberauth.Auth.{Credentials, Extra}

  # helpers for accessing configuration
  defp issuer(conn), do: Keyword.get(options(conn), :issuer)
  defp client_id(conn), do: Keyword.get(options(conn), :client_id)
  defp client_secret(conn), do: Keyword.get(options(conn), :client_secret)

  defp authorization_endpoint(config), do: config["authorization_endpoint"]
  defp token_endpoint(config), do: config["token_endpoint"]
  defp jwks_uri(config), do: config["jwks_uri"]

  # always add the openid scope
  defp scope(conn) do
    (Keyword.get(options(conn), :scope, []) ++ ["openid"])
    |> MapSet.new()
    |> Enum.join(" ")
  end

  # add some state to the request
  defp state(conn) do
    conn
    |> Phoenix.Token.encrypt(
      "Ueberauth.Strategy.OIDC",
      Keyword.get(options(conn), :state, %{})
    )
  end

  @openid_configuration_endpoint ".well-known/openid-configuration"

  # Get configuration from OpenID configuration path
  defp get_openid_config(conn) do
    uri =
      (issuer(conn) <> "/")
      |> URI.merge(@openid_configuration_endpoint)
      |> URI.to_string()

    headers = [{"Content-Type", "application/json"}]

    with {:ok, _, _, client_ref} <-
           :hackney.request(:get, uri, headers, <<>>, []) |> IO.inspect(),
         {:ok, body_binary} <- :hackney.body(client_ref),
         {:ok, body} <- Jason.decode(body_binary) do
      {:ok, body}
      |> IO.inspect()
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
      params: %{scope: scope(conn), state: state(conn)},
      redirect_uri: callback_url(conn),
      strategy: OAuth2.Strategy.AuthCode
    ]
    |> OAuth2.Client.new()
    |> OAuth2.Client.put_serializer("application/json", Jason)
  end

  def handle_request!(%Plug.Conn{} = conn) do
    with {:ok, config} <- get_openid_config(conn),
         client <- oauth_client(conn, config) do
      conn
      |> redirect!(OAuth2.Client.authorize_url!(client))
    end
  end

  # the subject identifier from the id_token is guaranteed to be a locally unique identifier
  def uid(conn), do: conn.private.ueberauth_oidc_id_token["sub"]

  def extra(conn) do
    %Extra{
      raw_info: %{
        issuer: issuer(conn),
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
         {:ok, state} <-
           Phoenix.Token.decrypt(conn, "Ueberauth.Strategy.OIDC", conn.params["state"],
             max_age: 600
           ),
         {:ok, client} <- OAuth2.Client.get_token(client, code: conn.params["code"]),
         {:ok, id_token} <- verify_id_token(conn, config, client) do
      conn
      |> put_private(:ueberauth_oidc_state, state)
      |> put_private(:ueberauth_oidc_oauth_client, client)
      |> put_private(:ueberauth_oidc_id_token, id_token)
    else
      _ ->
        conn
        |> set_errors!([error("oidc", "could not get access token")])
    end
  end

  # parse a Joken.Signer from the keys at the jwks endpoint
  defp parse_signer(key) do
    {:ok, Joken.Signer.create(key["alg"], key)}
  rescue
    _ ->
      {:error, "can not parse key from jwks_uri endpoint"}
  end

  # fetch keys from jwks_uri endpoint and return matching key as Jose.Signer
  defp get_signer(conn, config, kid) do
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
  defp verify_id_token(conn, config, client) do
    with jwt <- client.token.other_params["id_token"],
         {:ok, headers} <- Joken.peek_header(jwt),
         {:ok, signer} <- get_signer(conn, config, headers["kid"]) do
      Joken.verify(jwt, signer)
    end
  end
end
