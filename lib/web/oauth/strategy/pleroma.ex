defmodule CPub.Web.OAuth.Strategy.Pleroma do
  @moduledoc """
  Provides an Ueberauth strategy for Pleroma compatible providers.

  ## Configuration

  OAuth application (with its `client_id` and `client_secret`) is being registered
  on Pleroma instance dynamically and stored in the database.

  Include the Pleroma provider in your Ueberauth configuration:

      config :ueberauth, Ueberauth,
          providers: [
              ...
              pleroma: {CPub.Web.OAuth.Strategy.Pleroma, []}
          ]
  """

  use Ueberauth.Strategy,
    uid_field: :login,
    default_scope: "read",
    oauth2_module: __MODULE__.OAuth

  alias CPub.{Config, Repo}
  alias CPub.Web.OAuth.App

  alias Ueberauth.Auth.{Credentials, Extra, Info}

  @provider "pleroma"
  # @provider_verify_app_credentials_endpoint "/api/v1/apps/verify_credentials"
  @provider_register_app_endpoint "/api/v1/apps"
  @provider_verify_account_credentials_endpoint "/api/v1/accounts/verify_credentials"
  @app_scopes ["read"]

  @callback_endpoint "/oauth/pleroma/callback"

  @doc """
  Handles the initial redirect to the Pleroma compatible authentication page.

  Requires the `provider_url` param with Pleroma instance URL.

  The `state` param containing `provider_url` is included, it will be returned
  back by Pleroma instance.
  """
  @spec handle_request!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_request!(%Plug.Conn{params: %{"provider_url" => provider_url}} = conn) do
    case is_valid_provider_url(provider_url) do
      true ->
        opts = [state: provider_url]

        provider_url =
          provider_url
          |> URI.merge(@provider_register_app_endpoint)
          |> URI.to_string()

        case ensure_registered_oauth_app(provider_url) do
          {:ok, app} ->
            scopes = option(conn, :default_scope)
            module = option(conn, :oauth2_module)

            opts =
              Keyword.merge(opts,
                redirect_uri: callback_url(conn),
                scope: scopes,
                client_id: app.client_id,
                client_secret: app.client_secret
              )

            redirect!(conn, apply(module, :authorize_url!, [opts, [state: provider_url]]))

          {:error, reason} ->
            set_errors!(conn, [error("OAuth2", reason)])
        end

      false ->
        set_errors!(conn, [error("provider_url", "is invalid")])
    end
  end

  def handle_request!(%Plug.Conn{} = conn) do
    set_errors!(conn, [error("provider_url", "is missed")])
  end

  @doc """
  Handles the callback from Pleroma instance.

  When there is a failure from Pleroma instance the failure is included in the
  `ueberauth_failure` struct. Otherwise the information returned from Pleroma
  instance is returned in the `Ueberauth.Auth` struct.
  """
  @spec handle_callback!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_callback!(%Plug.Conn{params: %{"code" => code, "state" => state}} = conn) do
    opts = [redirect_uri: callback_url(conn)]
    module = option(conn, :oauth2_module)
    token = apply(module, :get_token!, [[code: code, state: state], opts])

    if token.access_token == nil do
      set_errors!(
        conn,
        [error(token.other_params["error"], token.other_params["error_description"])]
      )
    else
      fetch_user(conn, token)
    end
  end

  @doc """
  Called when no code is received from Pleroma instance.
  """
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection used for passing the raw Pleroma
  instance response around during the callback.
  """
  @spec handle_cleanup!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_cleanup!(conn) do
    conn
    |> put_private(:pleroma_user, nil)
    |> put_private(:pleroma_token, nil)
  end

  @doc """
  Fetches the uid field from the Pleroma instance response.

  This defaults to the option `username`.
  """
  @spec uid(Plug.Conn.t()) :: String.t()
  def uid(conn) do
    conn.private.pleroma_user["username"]
  end

  @doc """
  Includes the credentials from the Pleroma instance response.
  """
  @spec credentials(Plug.Conn.t()) :: Credentials.t()
  def credentials(conn) do
    token = conn.private.pleroma_token
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
  def info(conn) do
    user = conn.private.pleroma_user

    %Info{
      name: user["display_name"],
      nickname: user["username"],
      urls: %{
        followers_url: user["followers_url"],
        avatar_url: user["avatar"],
        blog: user["url"]
      }
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from the Pleroma
  instance callback.
  """
  @spec extra(Plug.Conn.t()) :: Extra.t()
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.pleroma_token,
        user: conn.private.pleroma_user
      }
    }
  end

  @spec is_valid_provider_url(String.t()) :: boolean
  defp is_valid_provider_url(provider_url) do
    uri = URI.parse(provider_url)

    !!(uri.scheme && uri.host)
  end

  @spec ensure_registered_oauth_app(String.t()) :: App.t()
  defp ensure_registered_oauth_app(provider_url) do
    app = Repo.get_by(App, %{provider: @provider, client_name: App.get_provider(provider_url)})

    case app do
      %App{} = app ->
        # T O D O : verify oauth app credentials
        {:ok, app}

      _ ->
        register_oauth_app_on_provider(provider_url)
    end
  end

  @spec register_oauth_app_on_provider(String.t()) :: {:ok, App.t()} | {:error, any}
  defp register_oauth_app_on_provider(provider_url) do
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(oauth_app_body())

    response = :hackney.request(:post, provider_url, headers, body, [])

    with {:ok, _resp_code, _headers, client} <- response,
         {:ok, body} <- :hackney.body(client),
         {:ok, body} <- Jason.decode(body, keys: :atoms) do
      case body do
        %{error: reason} ->
          {:error, reason}

        body ->
          body
          |> prepare_app_to_create(provider_url)
          |> App.create_from_provider()
      end
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, "Pleroma incompatible provider"}
    end
  end

  @spec oauth_app_body :: map
  defp oauth_app_body do
    client_name =
      Config.base_url()
      |> URI.parse()
      |> Map.get(:host)

    redirect_uris =
      Config.base_url()
      |> URI.merge(@callback_endpoint)
      |> URI.to_string()

    %{
      client_name: client_name,
      redirect_uris: redirect_uris,
      website: Config.base_url()
    }
  end

  @spec prepare_app_to_create(map, String.t()) :: map
  defp prepare_app_to_create(app, provider_url) do
    app
    |> Map.put(:provider, @provider)
    |> Map.put(:client_name, URI.parse(provider_url).host)
    |> Map.put(:scopes, @app_scopes)
    |> Map.put(:trusted, true)
    |> Map.put(:redirect_uris, app.redirect_uri)
    |> Map.drop([:id, :name, :redirect_uri, :vapid_key])
  end

  @spec fetch_user(Plug.Conn.t(), OAuth2.AccessToken.t()) :: Plug.Conn.t()
  defp fetch_user(%Plug.Conn{params: %{"state" => provider_url}} = conn, token) do
    token = %{token | other_params: Map.put(token.other_params, "provider_url", provider_url)}
    conn = put_private(conn, :pleroma_token, token)

    case __MODULE__.OAuth.get(token, @provider_verify_account_credentials_endpoint) do
      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        put_private(conn, :pleroma_user, user)

      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  @spec option(Plug.Conn.t(), map | String.t()) :: any
  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
