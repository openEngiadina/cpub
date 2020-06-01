defmodule CPub.Web.OAuth.Strategy.Pleroma do
  @moduledoc """
  Provides an Ueberauth strategy for Pleroma/Mastodon compatible providers.

  ## Configuration

  OAuth application (with its `client_id` and `client_secret`) is being registered
  on Pleroma/Mastodon instance dynamically and stored in the database.

  Include the Pleroma provider in your Ueberauth configuration:

      config :ueberauth, Ueberauth,
          providers: [
              ...
              pleroma: {CPub.Web.OAuth.Strategy.Pleroma, []}
          ]
  """

  use Ueberauth.Strategy,
    default_scope: "read",
    oauth2_module: __MODULE__.OAuth

  alias CPub.Config
  alias CPub.Web.OAuth.Strategy.Utils

  alias Ueberauth.Auth.{Credentials, Extra, Info}

  # @provider_verify_client_credentials_endpoint "/api/v1/apps/verify_credentials"
  @provider_register_client_endpoint "/api/v1/apps"
  @provider_verify_account_credentials_endpoint "/api/v1/accounts/verify_credentials"

  @doc """
  Handles the initial redirect to the Pleroma/Mastodon compatible authentication
  page.

  Requires the `provider_url` param with Pleroma/Mastodon instance URL.

  The `state` param containing `provider_url` is included, it will be returned
  back by Pleroma/Mastodon instance.
  """
  @spec handle_request!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_request!(%Plug.Conn{params: %{"provider_url" => provider_url}} = conn) do
    case Utils.is_valid_provider_url(provider_url) do
      true ->
        provider = Config.auth_provider_name(__MODULE__)
        scopes = option(conn, :default_scope)
        module = option(conn, :oauth2_module)
        apps_url = Utils.merge_uri(provider_url, @provider_register_client_endpoint)

        case Utils.ensure_registered_app(provider, apps_url, scopes) do
          {:ok, app} ->
            params = [
              redirect_uri: callback_url(conn),
              scope: scopes,
              client_id: app.client_id,
              client_secret: app.client_secret,
              state: provider_url
            ]

            client_opts = [
              state: provider_url,
              client_id: app.client_id,
              client_secret: app.client_secret
            ]

            redirect!(conn, apply(module, :authorize_url!, [params, client_opts]))

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
  Handles the callback from Pleroma/Mastodon instance.

  When there is a failure from Pleroma/Mastodon instance the failure is included
  in the `ueberauth_failure` struct. Otherwise the information returned from
  Pleroma/Mastodon instance is returned in the `Ueberauth.Auth` struct.
  """
  @spec handle_callback!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_callback!(%Plug.Conn{params: %{"code" => code, "state" => state}} = conn) do
    opts = [redirect_uri: callback_url(conn)]
    module = option(conn, :oauth2_module)
    token = apply(module, :get_token!, [[code: code, state: state], opts])
    token = %{token | other_params: Map.put(token.other_params, "provider_url", state)}

    if token.access_token != nil do
      conn = put_private(conn, :provider_token, token)
      Utils.fetch_user(conn, module.get(token, @provider_verify_account_credentials_endpoint))
    else
      %{other_params: %{"error" => error, "error_description" => error_description}} = token
      set_errors!(conn, [error(error, error_description)])
    end
  end

  @doc """
  Called when no code is received from Pleroma/Mastodon instance.
  """
  def handle_callback!(%Plug.Conn{} = conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection used for passing the raw
  Pleroma/Mastodon instance response around during the callback.
  """
  @spec handle_cleanup!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_cleanup!(%Plug.Conn{} = conn) do
    conn
    |> put_private(:provider_user, nil)
    |> put_private(:provider_token, nil)
  end

  @doc """
  Fetches the uid field from the Pleroma/Mastodon instance response.

  This defaults to the option `username`.
  """
  @spec uid(Plug.Conn.t()) :: String.t()
  def uid(%Plug.Conn{private: %{provider_user: %{"username" => username}}}), do: username

  @doc """
  Includes the credentials from the Pleroma/Mastodon instance response.
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
  def info(%Plug.Conn{private: %{provider_user: user}}) do
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
  Stores the raw information (including the token) obtained from the
  Pleroma/Mastodon instance callback.
  """
  @spec extra(Plug.Conn.t()) :: Extra.t()
  def extra(%Plug.Conn{private: %{provider_user: user, provider_token: token}}) do
    %Extra{raw_info: %{token: token, user: user}}
  end

  @spec option(Plug.Conn.t(), atom | String.t()) :: any
  defp option(%Plug.Conn{} = conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
