defmodule CPub.Web.OIDC.OIDCController do
  use CPub.Web, :controller

  alias CPub.{Config, User}

  @doc """
  Provides OpenID Provider Metadata.
  https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata
  """
  @spec provider_metadata(Plug.Conn.t(), map) :: Plug.Conn.t()
  def provider_metadata(%Plug.Conn{} = conn, _params) do
    provider_metadata = %{
      issuer: url(""),
      authorization_endpoint: url(Routes.o_auth_path(conn, :create_authorization)),
      token_endpoint: url(Routes.o_auth_path(conn, :exchange_token)),
      revocation_endpoint: url(Routes.o_auth_path(conn, :revoke_token)),
      userinfo_endpoint: url(Routes.oidc_path(conn, :user_info)),
      jwks_uri: url(Routes.oidc_path(conn, :json_web_key_set)),
      registration_endpoint: url(Routes.app_path(conn, :create)),
      scopes_supported: ["read", "openid"],
      response_types_supported: ["code", "token", "id_token token"],
      response_modes_supported: ["query", "fragment"],
      grant_types_supported: [
        "authorization_code",
        "refresh_token",
        "password",
        "client_credentials"
      ],
      subject_types_supported: ["public"],
      id_token_signing_alg_values_supported: ["RS256"],
      token_endpoint_auth_methods_supported: ["client_secret_basic", "client_secret_post"],
      claim_types_supported: ["normal"],
      claims_supported: ["iss", "sub", "exp", "iat"],
      claims_parameter_supported: false,
      request_parameter_supported: false,
      request_uri_parameter_supported: false,
      require_request_uri_registration: false
    }

    json(conn, provider_metadata)
  end

  @doc """
  Returns claims about the authenticated user.
  https://openid.net/specs/openid-connect-core-1_0.html#UserInfo
  """
  @spec user_info(Plug.Conn.t(), map) :: Plug.Conn.t()
  def user_info(%Plug.Conn{assigns: %{user: %User{username: username}}} = conn, _params) do
    user_info = %{nickname: username}

    json(conn, user_info)
  end

  @doc """
  Returns JSON Web Key Set document.
  https://tools.ietf.org/html/draft-ietf-jose-json-web-key-41
  """
  @spec json_web_key_set(Plug.Conn.t(), map) :: Plug.Conn.t()
  def json_web_key_set(%Plug.Conn{} = conn, _params) do
    keys = %{keys: []}

    json(conn, keys)
  end

  @spec url(String.t()) :: String.t()
  def url(endpoint) do
    Config.base_url()
    |> URI.merge(endpoint)
    |> URI.to_string()
  end
end
