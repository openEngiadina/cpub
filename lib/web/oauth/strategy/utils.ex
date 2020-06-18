defmodule CPub.Web.OAuth.Strategy.Utils do
  @moduledoc """
  Util functions for dealing with OAuth2 strategies.
  """

  use Ueberauth.Strategy

  alias CPub.Config
  alias CPub.Solid.WebID.Profile
  alias CPub.Web.HTTP
  alias CPub.Web.OAuth.{App, OIDCController}

  alias RDF.Turtle

  @doc """
  Discovers identity provider for the provided url:
  https://github.com/solid/webid-oidc-spec/blob/master/README.md#authorized-oidc-issuer-discovery
  """
  @spec identity_provider(String.t()) :: {:ok, String.t()}
  def identity_provider(url) do
    case discover_issuer_from_headers(url) do
      {:ok, identity_provider} ->
        {:ok, identity_provider}

      _ ->
        case discover_issuer_from_web_id(url) do
          {:ok, identity_provider} -> {:ok, identity_provider}
          _ -> {:ok, url}
        end
    end
  end

  @spec discover_issuer_from_web_id(String.t()) :: {:ok, String.t()} | {:error, atom}
  def discover_issuer_from_web_id(url) do
    provider = App.get_provider(url)
    [protocol, _] = String.split(url, provider)
    base_iri = "#{protocol}#{provider}"

    with {:ok, body, _} <- HTTP.request(:get, url, %{}, [{"Accept", "text/turtle"}]),
         {:ok, user} <- Turtle.Decoder.decode(body, base_iri: base_iri),
         issuer when is_binary(issuer) <- fetch_issuer_from_web_id_profile(user) do
      {:ok, issuer}
    else
      _ ->
        {:error, :unsupported}
    end
  end

  @spec fetch_issuer_from_web_id_profile(RDF.Graph.t()) :: String.t()
  def fetch_issuer_from_web_id_profile(%RDF.Graph{} = user) do
    user
    |> Profile.fetch_profile()
    |> Profile.fetch_oidc_issuer()
  end

  @spec discover_issuer_from_headers(String.t()) :: {:ok, String.t()} | {:error, atom}
  def discover_issuer_from_headers(url) do
    with {:ok, _, headers} <- HTTP.request(:options, url),
         {"Link", header} <- Enum.find(headers, fn {h, _} -> h == "Link" end),
         issuer when is_binary(issuer) <- fetch_issuer_from_link_header(header) do
      {:ok, issuer}
    else
      _ ->
        {:error, :unsupported}
    end
  end

  @spec fetch_issuer_from_link_header(String.t()) :: String.t()
  defp fetch_issuer_from_link_header(header) do
    rel =
      header
      |> String.split()
      |> Enum.chunk_every(2)
      |> Enum.find(fn [_, rel] -> String.contains?(rel, OIDCController.issuer_rel()) end)
      |> hd()

    Regex.named_captures(~r/<(?<url>.+)>/, rel)["url"]
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

  @spec request(String.t(), atom, String.t(), map) :: {:ok, map} | {:error, String.t()}
  defp request(provider, method, url, body \\ %{}) do
    with {:ok, body, _} <- HTTP.request(method, url, body),
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
    redirect_uris = HTTP.merge_uri(Config.base_url(), callback_endpoint)

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
