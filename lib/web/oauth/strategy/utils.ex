defmodule CPub.Web.OAuth.Strategy.Utils do
  @moduledoc """
  Util functions for dealing with OAuth2 strategies.
  """

  use Ueberauth.Strategy

  alias CPub.Config
  alias CPub.Web.OAuth.App

  @spec merge_uri(String.t(), String.t()) :: String.t()
  def merge_uri(site, endpoint) do
    site
    |> URI.merge(endpoint)
    |> URI.to_string()
  end

  @spec is_valid_provider_url(String.t()) :: boolean
  def is_valid_provider_url(provider_url) do
    uri = URI.parse(provider_url)

    !!(uri.scheme && uri.host)
  end

  @spec ensure_registered_app(String.t(), String.t(), [String.t()]) ::
          {:ok, App.t()} | {:error, any}
  def ensure_registered_app(provider, apps_url, scopes) do
    app = App.get_by(%{provider: provider, client_name: App.get_provider(apps_url)})

    case app do
      %App{} = app ->
        # T O D O : verify oauth app credentials
        {:ok, app}

      nil ->
        register_app_on_provider(provider, apps_url, scopes)
    end
  end

  @spec register_app_on_provider(String.t(), String.t(), [String.t()]) ::
          {:ok, App.t()} | {:error, any}
  defp register_app_on_provider(provider, apps_url, scopes) do
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(oauth_app_body(provider, scopes))

    response = :hackney.request(:post, apps_url, headers, body, [])

    with {:ok, _resp_code, _headers, client} <- response,
         {:ok, body} <- :hackney.body(client),
         {:ok, body} <- Jason.decode(body, keys: :atoms) do
      case body do
        %{error: reason} ->
          {:error, reason}

        body ->
          body
          |> prepare_app_to_create(provider, apps_url, scopes)
          |> App.create_from_provider()
      end
    else
      {:error, :nxdomain} ->
        {:error, "Invalid Provider URL"}

      {:error, _} ->
        {:error, "#{provider} incompatible provider"}
    end
  end

  @spec oauth_app_body(String.t(), [String.t()]) :: map
  defp oauth_app_body(provider, scopes) do
    client_name = "#{App.get_provider(Config.base_url())}_#{provider}"
    callback_endpoint = callback_endpoint(provider)
    redirect_uris = merge_uri(Config.base_url(), callback_endpoint)

    %{
      client_name: client_name,
      redirect_uris: redirect_uris,
      website: Config.base_url(),
      scopes: scopes
    }
  end

  @spec prepare_app_to_create(map, String.t(), String.t(), [String.t()]) :: map
  defp prepare_app_to_create(app, provider, provider_url, scopes) do
    app
    |> Map.put(:provider, provider)
    |> Map.put(:client_name, App.get_provider(provider_url))
    |> Map.put(:scopes, List.wrap(app[:scopes] || app[:scope] || scopes))
    |> Map.put(:trusted, true)
    |> Map.put(:redirect_uris, app.redirect_uri)
    |> Map.drop([:id, :name, :redirect_uri, :vapid_key])
  end

  @spec callback_endpoint(String.t()) :: String.t()
  defp callback_endpoint("oidc_" <> _), do: "/auth/oidc/callback"
  defp callback_endpoint(provider), do: "/auth/#{provider}/callback"

  @spec fetch_user(
          Plug.Conn.t(),
          {:ok, OAuth2.Response.t()} | {:error, %OAuth2.Error{}}
        ) :: Plug.Conn.t()
  def fetch_user(%Plug.Conn{} = conn, verify_user_response) do
    case verify_user_response do
      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        put_private(conn, :provider_user, user)

      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end
end
