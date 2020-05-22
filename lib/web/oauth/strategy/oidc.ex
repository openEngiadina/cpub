defmodule CPub.Web.OAuth.Strategy.OIDC do
  @moduledoc """
  Provides an Ueberauth strategy for OpenID Connect compatible providers.

  ## Configuration

  Register an OAuth2 application with the `openid` scope and
  the "<BASE_URL>/auth/oidc/callback" callback URL on a provider and get
  the `client_id` and `client_secret` values.

  Include a provider in your Ueberauth configuration:

      config :ueberauth, Ueberauth,
          providers: [
              ...
              oidc: {CPub.Web.OAuth.Strategy.OIDC, []}
          ]

  Then include the configuration for a provider.

      config :ueberauth, CPub.Web.OAuth.Strategy.OIDC.OAuth,
          ...
          oidc_<provider>: [
              site: "<provider_url>",
              authorize_url: "<provider_authorize_url>",
              token_url: "<provider_token_url>",
              client_id: System.get_env("OIDC_<PROVIDER>_CLIENT_ID"),
              client_secret: System.get_env("OIDC_<PROVIDER>_CLIENT_SECRET")
          ]
  """

  use Ueberauth.Strategy,
    default_scope: "openid",
    oauth2_module: __MODULE__.OAuth

  alias Ueberauth.Auth.{Credentials, Extra, Info}

  @doc """
  Handles the initial redirect to the OpenID Connect compatible authentication
  page.

  The `state` param containing `provider` is included, it will be returned back
  by a provider.
  """
  @spec handle_request!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_request!(%Plug.Conn{params: %{"provider" => "oidc", "state" => state}} = conn) do
    scopes = option(conn, :default_scope)
    module = option(conn, :oauth2_module)

    params = [redirect_uri: redirect_uri(conn, state), scope: scopes, state: state]
    client_opts = [provider: state]

    redirect!(conn, apply(module, :authorize_url!, [params, client_opts]))
  end

  def handle_request!(%Plug.Conn{} = conn) do
    set_errors!(conn, [error("provider", "is missed")])
  end

  @doc """
  Handles the callback from OpenID Connect compatible instance.

  When there is a failure from a provider the failure is included
  in the `ueberauth_failure` struct. Otherwise the information returned from
  a provider instance is returned in the `Ueberauth.Auth` struct.
  """
  @spec handle_callback!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_callback!(%Plug.Conn{params: %{"code" => code, "state" => state}} = conn) do
    redirect_uri = redirect_uri(conn, state)
    opts = [redirect_uri: redirect_uri]
    module = option(conn, :oauth2_module)
    params = [code: code, redirect_uri: redirect_uri, state: state]

    %OAuth2.AccessToken{other_params: %{"id_token" => _}} =
      token = apply(module, :get_token!, [params, opts])

    if token.access_token != nil do
      fetch_user(conn, token)
    else
      %{other_params: %{"error" => error, "error_description" => error_description}} = token
      set_errors!(conn, [error(error, error_description)])
    end
  end

  @doc """
  Called when no code is received from a provider.
  """
  def handle_callback!(%Plug.Conn{} = conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection used for passing the raw provider
  response around during the callback.
  """
  @spec handle_cleanup!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_cleanup!(%Plug.Conn{} = conn) do
    conn
    |> put_private(:oidc_user, nil)
    |> put_private(:oidc_token, nil)
  end

  @doc """
  Fetches the uid field from a provider response.

  This defaults to the option `nickname`.
  """
  @spec uid(Plug.Conn.t()) :: String.t()
  def uid(%Plug.Conn{private: %{oidc_user: %{"nickname" => username}}}) do
    username
  end

  @doc """
  Includes the credentials from a provider response.
  """
  @spec credentials(Plug.Conn.t()) :: Credentials.t()
  def credentials(%Plug.Conn{private: %{oidc_token: token}}) do
    scopes = String.split(token.other_params["scope"] || "", ",")

    %Credentials{
      token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type,
      expires: !!token.expires_at,
      scopes: scopes
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  @spec info(Plug.Conn.t()) :: Info.t()
  def info(%Plug.Conn{private: %{oidc_user: user}}) do
    %Info{
      name: user["name"],
      nickname: user["nickname"],
      email: user["email"],
      image: user["picture"]
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from a provider
  callback.
  """
  @spec extra(Plug.Conn.t()) :: Extra.t()
  def extra(%Plug.Conn{private: %{oidc_user: user, oidc_token: token}}) do
    %Extra{raw_info: %{token: token, user: user}}
  end

  @spec redirect_uri(Plug.Conn.t(), String.t()) :: String.t()
  defp redirect_uri(%Plug.Conn{} = conn, provider) do
    conn
    |> callback_url()
    |> String.replace("oidc_#{provider}", "oidc")
  end

  @spec fetch_user(Plug.Conn.t(), OAuth2.AccessToken.t()) :: Plug.Conn.t()
  defp fetch_user(%Plug.Conn{params: %{"state" => provider}} = conn, token) do
    token = %{token | other_params: Map.put(token.other_params, "provider", provider)}
    conn = put_private(conn, :oidc_token, token)

    case __MODULE__.OAuth.get(token) do
      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        put_private(conn, :oidc_user, user)

      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  @spec option(Plug.Conn.t(), atom | String.t()) :: any
  defp option(%Plug.Conn{} = conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
