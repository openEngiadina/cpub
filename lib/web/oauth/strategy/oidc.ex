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
              authorize_url: "<provider_authorize_url_or_endpoint>",
              token_url: "<provider_token_url_or_endpoint>",
              userinfo_url: "<provider_userinfo_url_or_endpoint>",
              client_id: System.get_env("OIDC_<PROVIDER>_CLIENT_ID"),
              client_secret: System.get_env("OIDC_<PROVIDER>_CLIENT_SECRET")
          ]

  Alternatively an OAuth application is being registered dynamically on
  OpenID Connect compatible providers with multiple instances like CPub itself.
  A provider instance is defined in the `provider_url` param.

  Include the next configuration for such providers:

      config :ueberauth, CPub.Web.OAuth.Strategy.OIDC.OAuth,
          ...
          oidc_<provider>: [
              authorize_url: "<provider_authorize_endpoint>",
              token_url: "<provider_token_endpoint>",
              userinfo_url: "<provider_userinfo_endpoint>"
          ]
  """

  use Ueberauth.Strategy,
    default_scope: "openid",
    oauth2_module: __MODULE__.OAuth

  alias CPub.Config
  alias CPub.Web.OAuth.Strategy.Utils

  alias Ueberauth.Auth.{Credentials, Extra, Info}

  @provider "oidc"

  @doc """
  Handles the initial redirect to the OpenID Connect compatible authentication
  page.

  The `state` param containing `provider` is included, it will be returned back
  by a provider.
  """
  @spec handle_request!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_request!(
        %Plug.Conn{params: %{"provider" => "oidc", "oidc_provider" => oidc_provider}} = conn
      ) do
    case multi_instances?(oidc_provider) do
      false -> handle_request_for_single_instance(conn)
      true -> handle_request_for_multi_instances(conn)
    end
  end

  def handle_request!(%Plug.Conn{} = conn) do
    set_errors!(conn, [error("provider", "is missed")])
  end

  @spec handle_request_for_single_instance(Plug.Conn.t()) :: Plug.Conn.t()
  defp handle_request_for_single_instance(
         %Plug.Conn{
           params: %{"provider" => "oidc", "oidc_provider" => oidc_provider}
         } = conn
       ) do
    scopes = option(conn, :default_scope)
    module = option(conn, :oauth2_module)
    state = Jason.encode!(%{"oidc_provider" => oidc_provider})
    client_opts = [state: state]

    params = [
      redirect_uri: redirect_uri(conn, oidc_provider),
      scope: scopes,
      state: state
    ]

    redirect!(conn, apply(module, :authorize_url!, [params, client_opts]))
  end

  @spec handle_request_for_multi_instances(Plug.Conn.t()) :: Plug.Conn.t()
  defp handle_request_for_multi_instances(
         %Plug.Conn{
           params: %{
             "provider" => "oidc",
             "oidc_provider" => oidc_provider,
             "provider_url" => provider_url
           }
         } = conn
       ) do
    scopes = option(conn, :default_scope)
    module = option(conn, :oauth2_module)
    config_opts = Config.oidc_provider_opts(oidc_provider)

    case Utils.is_valid_provider_url(provider_url) do
      true ->
        apps_url = Utils.merge_uri(provider_url, config_opts[:register_client_url])

        case Utils.ensure_registered_app("#{@provider}_#{oidc_provider}", apps_url, scopes) do
          {:ok, app} ->
            state =
              %{"provider_url" => provider_url, "oidc_provider" => oidc_provider}
              |> Jason.encode!()

            client_opts = [
              state: state,
              client_id: app.client_id,
              client_secret: app.client_secret
            ]

            params = [
              redirect_uri: callback_url(conn),
              scope: scopes,
              client_id: app.client_id,
              client_secret: app.client_secret,
              state: state
            ]

            redirect!(conn, apply(module, :authorize_url!, [params, client_opts]))
        end

      false ->
        set_errors!(conn, [error("provider_url", "is invalid")])
    end
  end

  @doc """
  Handles the callback from OpenID Connect compatible instance.

  When there is a failure from a provider the failure is included
  in the `ueberauth_failure` struct. Otherwise the information returned from
  a provider instance is returned in the `Ueberauth.Auth` struct.
  """
  @spec handle_callback!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_callback!(%Plug.Conn{params: %{"code" => code, "state" => state}} = conn) do
    decoded_state = Jason.decode!(state)
    oidc_provider = decoded_state["oidc_provider"]
    redirect_uri = redirect_uri(conn, oidc_provider)
    opts = [redirect_uri: redirect_uri]
    module = option(conn, :oauth2_module)

    params = [code: code, redirect_uri: redirect_uri, state: state]

    %OAuth2.AccessToken{other_params: %{"id_token" => _}} =
      token = apply(module, :get_token!, [params, opts])

    token = %{
      token
      | other_params:
          token.other_params
          |> Map.put("oidc_provider", oidc_provider)
          |> Map.put("provider_url", decoded_state["provider_url"])
    }

    if token.access_token != nil do
      conn = put_private(conn, :provider_token, token)
      Utils.fetch_user(conn, module.get(token))
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

  This defaults to the option `nickname`.
  """
  @spec uid(Plug.Conn.t()) :: String.t()
  def uid(%Plug.Conn{private: %{provider_user: user}}) do
    user["nickname"] || user["username"]
  end

  @doc """
  Includes the credentials from a provider response.
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
  def extra(%Plug.Conn{private: %{provider_user: user, provider_token: token}}) do
    %Extra{raw_info: %{token: token, user: user}}
  end

  @spec multi_instances?(String.t()) :: boolean
  def multi_instances?(oidc_provider) do
    "oidc_#{oidc_provider}" in Config.auth_multi_instances_consumer_strategies()
  end

  @spec redirect_uri(Plug.Conn.t(), String.t()) :: String.t()
  defp redirect_uri(%Plug.Conn{} = conn, oidc_provider) do
    conn
    |> callback_url()
    |> String.replace("oidc_#{oidc_provider}", "oidc")
  end

  @spec option(Plug.Conn.t(), atom | String.t()) :: any
  defp option(%Plug.Conn{} = conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
