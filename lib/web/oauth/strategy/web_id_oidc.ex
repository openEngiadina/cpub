defmodule CPub.Web.OAuth.Strategy.WebIDOIDC do
  @moduledoc """
  Provides an Ueberauth strategy for WebID-OIDC (Solid) compatible providers.

  ## Configuration

  OAuth application (with its `client_id` and `client_secret`) is being registered
  on WebID-OIDC instance dynamically and stored in the database.

  Include the WebID-OIDC provider in your Ueberauth configuration:

      config :ueberauth, Ueberauth,
          providers: [
              ...
              solid: {CPub.Web.OAuth.Strategy.WebIDOIDC, []}
          ]
  """

  use Ueberauth.Strategy,
    default_scope: "openid",
    oauth2_module: __MODULE__.OAuth

  alias CPub.Config
  alias CPub.NS.FOAF
  alias CPub.Solid.WebID.Profile
  alias CPub.Web.HTTP
  alias CPub.Web.OAuth.Strategy.Utils

  alias Ueberauth.Auth.{Credentials, Extra, Info}

  @provider_metadata_endpoint "/.well-known/openid-configuration"

  @doc """
  Handles the initial redirect to the WebID-OIDC compatible authentication page.

  Requires the `provider_url` param with a WebID-OIDC compatible instance URL.

  The `state` param containing `provider_url` is included, it will be returned
  back by a instance.
  """
  @spec handle_request!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_request!(%Plug.Conn{params: %{"provider_url" => provider_url}} = conn) do
    provider = Config.auth_provider_name(__MODULE__)
    scopes = option(conn, :default_scope)
    module = option(conn, :oauth2_module)
    {:ok, identity_provider} = Utils.identity_provider(provider_url)
    provider_metadata_url = HTTP.merge_uri(identity_provider, @provider_metadata_endpoint)

    with {:ok, metadata} <- Utils.provider_metadata(provider, provider_metadata_url),
         registration_endpoint when not is_nil(registration_endpoint) <-
           metadata[:registration_endpoint],
         apps_url <- HTTP.merge_uri(identity_provider, registration_endpoint),
         {:ok, app} <-
           Utils.ensure_registered_app(provider, apps_url, scopes, metadata) do
      client_opts = [
        state: identity_provider,
        client_id: app.client_id,
        client_secret: app.client_secret
      ]

      params = [
        redirect_uri: callback_url(conn),
        scope: scopes,
        client_id: app.client_id,
        client_secret: app.client_secret,
        state: identity_provider
      ]

      redirect!(conn, apply(module, :authorize_url!, [params, client_opts]))
    else
      {:error, reason} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  def handle_request!(%Plug.Conn{} = conn) do
    set_errors!(conn, [error("provider_url", "is missed")])
  end

  @doc """
  Handles the callback from WebID-OIDC compatible instance.

  When there is a failure from a provider the failure is included
  in the `ueberauth_failure` struct. Otherwise the information returned from
  a provider instance is returned in the `Ueberauth.Auth` struct.
  """
  @spec handle_callback!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_callback!(%Plug.Conn{params: %{"code" => code, "state" => state}} = conn) do
    module = option(conn, :oauth2_module)

    params = [code: code, state: state]
    opts = [redirect_uri: callback_url(conn) |> List.wrap() |> List.first()]

    %OAuth2.AccessToken{other_params: %{"id_token" => _}} =
      token = apply(module, :get_token!, [params, opts])

    token = %{token | other_params: Map.put(token.other_params, "provider_url", state)}

    if token.access_token != nil do
      conn = put_private(conn, :provider_token, token)
      fetch_user(conn, module.get(token))
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
    |> put_private(:provider_user, nil)
    |> put_private(:provider_token, nil)
  end

  @doc """
  Fetches the uid field from a provider response.
  """
  @spec uid(Plug.Conn.t()) :: String.t()
  def uid(%Plug.Conn{private: %{provider_user: %RDF.Graph{} = user}}) do
    profile = Profile.fetch_profile(user)

    (profile[FOAF.nick()] || profile[FOAF.name()])
    |> fetch_literal()
    |> to_snake_case()
  end

  @doc """
  Includes the credentials from an instance response.
  """
  @spec credentials(Plug.Conn.t()) :: Credentials.t()
  def credentials(%Plug.Conn{private: %{provider_token: token}}) do
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
  def info(%Plug.Conn{private: %{provider_user: %RDF.Graph{} = user}}) do
    profile = Profile.fetch_profile(user)

    name =
      profile[FOAF.name()]
      |> fetch_literal()
      |> to_snake_case()

    nickname =
      (profile[FOAF.nick()] || profile[FOAF.name()])
      |> fetch_literal()
      |> to_snake_case()

    %Info{name: name, nickname: nickname}
  end

  @doc """
  Stores the raw information (including the token) obtained from an instance
  callback.
  """
  @spec extra(Plug.Conn.t()) :: Extra.t()
  def extra(%Plug.Conn{private: %{provider_user: user, provider_token: token}}) do
    %Extra{raw_info: %{token: token, user: user}}
  end

  @spec provider :: String.t() | nil
  def provider, do: Config.auth_provider_name(__MODULE__)

  @spec option(Plug.Conn.t(), atom | String.t()) :: any
  defp option(%Plug.Conn{} = conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end

  @spec fetch_literal([RDF.Literal.t()]) :: String.t()
  defp fetch_literal([%RDF.Literal{} = literal]), do: RDF.Literal.canonical_lexical(literal)

  @spec to_snake_case(String.t()) :: String.t()
  defp to_snake_case(str), do: str |> String.replace(" ", "_") |> String.downcase()

  @spec fetch_user(Plug.Conn.t(), {:ok, RDF.Graph.t()} | {:error, any}) :: Plug.Conn.t()
  defp fetch_user(conn, user_response) do
    case user_response do
      {:ok, user} ->
        put_private(conn, :provider_user, user)

      {:error, :unauthorized_issuer} ->
        set_errors!(conn, [error("OAuth2", "Unauthorized issuer.")])

      {:error, reason} ->
        set_errors!(conn, [error("OAuth2", "#{reason}")])
    end
  end
end
