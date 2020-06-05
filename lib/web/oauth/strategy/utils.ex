defmodule CPub.Web.OAuth.Strategy.Utils do
  @moduledoc """
  Util functions for dealing with OAuth2 strategies.
  """

  use Ueberauth.Strategy

  alias CPub.Config
  alias CPub.Web.OAuth.App

  @spec http_request(atom, String.t(), map) :: {:ok, String.t()} | {:error, any}
  def http_request(method, url, body \\ %{}) do
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(body)
    response = :hackney.request(method, url, headers, body, [])

    with true <- is_valid_url(url),
         {:ok, _resp_code, _headers, client} <- response,
         {:ok, body} <- :hackney.body(client) do
      {:ok, body}
    else
      false ->
        {:error, :invalid_url}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec merge_uri(String.t(), String.t()) :: String.t()
  def merge_uri(site, endpoint) do
    site
    |> URI.merge(endpoint)
    |> URI.to_string()
  end

  @spec provider_metadata(String.t(), String.t()) :: {:ok, map} | {:error, any}
  def provider_metadata(provider, provider_metadata_url) do
    request(provider, :get, provider_metadata_url)
  end

  @spec ensure_registered_app(String.t(), String.t(), [String.t()], map) ::
          {:ok, App.t()} | {:error, any}
  def ensure_registered_app(provider, apps_url, scopes, metadata \\ %{}) do
    app = App.get_by(%{provider: provider, client_name: App.get_provider(apps_url)})

    case app do
      %App{} = app ->
        # T O D O : verify oauth app credentials
        {:ok, app}

      nil ->
        register_app_on_provider(provider, apps_url, scopes, metadata)
    end
  end

  @spec register_app_on_provider(String.t(), String.t(), [String.t()], map) ::
          {:ok, App.t()} | {:error, any}
  defp register_app_on_provider(provider, apps_url, scopes, metadata) do
    body = oauth_app_body(provider, scopes)

    # Because of different providers could expect different types for
    # redirect_uris (either string or array) we try both cases
    result =
      case request(provider, :post, apps_url, body) do
        {:ok, %{error: _}} ->
          body = %{body | redirect_uris: List.wrap(body.redirect_uris)}
          request(provider, :post, apps_url, body)

        {:ok, %{errors: _}} ->
          body = %{body | redirect_uris: List.wrap(body.redirect_uris)}
          request(provider, :post, apps_url, body)

        {:ok, app} ->
          {:ok, app}

        {:error, reason} ->
          {:error, reason}
      end

    with {:ok, app} <- result do
      app
      |> prepare_app_to_create(provider, apps_url, scopes, metadata)
      |> App.create_from_provider()
    end
  end

  @spec is_valid_url(String.t()) :: boolean
  defp is_valid_url(provider_url) do
    with uri <- URI.parse(provider_url), do: !!(uri.scheme && uri.host)
  end

  @spec request(String.t(), atom, String.t(), map) :: {:ok, map} | {:error, String.t()}
  defp request(provider, method, url, body \\ %{}) do
    with {:ok, body} <- http_request(method, url, body),
         {:ok, decoded_body} <- Jason.decode(body, keys: :atoms) do
      {:ok, decoded_body}
    else
      {:error, reason} when reason in [:invalid_url, :nxdomain] ->
        {:error, "Invalid provider URL"}

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

  @spec prepare_app_to_create(map, String.t(), String.t(), [String.t()], map) :: map
  defp prepare_app_to_create(app, provider, provider_url, scopes, metadata) do
    app
    |> Map.put(:provider, provider)
    |> Map.put(:client_name, App.get_provider(provider_url))
    |> Map.put(:scopes, prepare_scopes(app[:scopes] || app[:scope] || scopes))
    |> Map.put(:trusted, true)
    |> Map.put(:metadata, metadata)
    |> Map.put(:redirect_uris, List.wrap(app[:redirect_uri] || app[:redirect_uris]))
    |> Map.drop([:id, :name, :redirect_uri, :vapid_key])
  end

  @spec prepare_scopes(String.t() | [String.t()]) :: [String.t()]
  defp prepare_scopes(scopes) when is_binary(scopes), do: String.split(scopes)
  defp prepare_scopes(scopes) when is_list(scopes), do: scopes

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
