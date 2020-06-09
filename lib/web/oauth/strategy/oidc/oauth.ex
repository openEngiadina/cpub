defmodule CPub.Web.OAuth.Strategy.OIDC.OAuth do
  @moduledoc """
  An implementation of OAuth2 for OpenID Connect compatible providers.
  """

  use OAuth2.Strategy

  alias CPub.Config
  alias CPub.Web.HTTP
  alias CPub.Web.OAuth.App
  alias CPub.Web.OAuth.Strategy.{OIDC, Utils}

  alias OAuth2.{AccessToken, Client, Response, Strategy}

  @provider_metadata_endpoint "/.well-known/openid-configuration"

  @doc """
  Construct a client for requests to Github.

  Optionally include any OAuth2 options here to be merged with the defaults.

  This will be setup automatically for you in `CPub.Web.OAuth.Strategy.OIDC`.
  These options are only useful for usage outside the normal callback phase of
  Ueberauth.
  """
  @spec client(keyword) :: Client.t()
  def client(opts \\ []) do
    state = Jason.decode!(opts[:state])
    oidc_provider = state["oidc_provider"]
    config_opts = Config.oidc_provider_opts(oidc_provider)

    case OIDC.multi_instances?(oidc_provider) do
      true ->
        site = state["provider_url"]
        authorize_url = HTTP.merge_uri(site, config_opts[:authorize_url])
        token_url = HTTP.merge_uri(site, config_opts[:token_url])

        [strategy: __MODULE__, site: site, authorize_url: authorize_url, token_url: token_url]
        |> Keyword.merge(Keyword.delete(opts, :state))
        |> Client.new()

      false ->
        [strategy: __MODULE__]
        |> Keyword.merge(config_opts)
        |> Keyword.merge(Keyword.delete(opts, :state))
        |> Client.new()
    end
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth.
  """
  @spec authorize_url!(keyword, keyword) :: String.t()
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> Client.authorize_url!(params)
  end

  @spec get(AccessToken.t(), keyword, keyword) :: {:ok, Response.t()} | {:error, any}
  def get(
        %AccessToken{other_params: %{"oidc_provider" => oidc_provider} = params} = token,
        headers \\ [],
        opts \\ []
      ) do
    {url, params} =
      case OIDC.multi_instances?(oidc_provider) do
        true ->
          {:ok, provider_metadata} =
            Utils.provider_metadata(
              "oidc_#{oidc_provider}",
              HTTP.merge_uri(params["provider_url"], @provider_metadata_endpoint)
            )

          url = provider_metadata[:userinfo_endpoint]
          state = %{"oidc_provider" => oidc_provider, "provider_url" => params["provider_url"]}

          params =
            [token: token, state: Jason.encode!(state)]
            |> complete_params_from_app(oidc_provider, params["provider_url"])

          {url, params}

        false ->
          url = Config.oidc_provider_opts(oidc_provider)[:userinfo_url]

          params =
            [token: token, state: Jason.encode!(%{"oidc_provider" => oidc_provider})]
            |> complete_params_from_config(oidc_provider)

          {url, params}
      end

    params
    |> client()
    |> Client.get(url, headers, opts)
  end

  @spec get_token!(keyword, keyword) :: AccessToken.t()
  def get_token!(params \\ [], options \\ []) do
    headers = Keyword.get(options, :headers, [])
    options = Keyword.get(options, :options, [])
    decoded_state = Jason.decode!(params[:state])
    oidc_provider = decoded_state["oidc_provider"]
    provider_url = decoded_state["provider_url"]

    params =
      case OIDC.multi_instances?(oidc_provider) do
        true -> complete_params_from_app(params, oidc_provider, provider_url)
        false -> complete_params_from_config(params, oidc_provider)
      end

    client = Client.get_token!(client(params), params, headers, options)

    client.token
  end

  @spec complete_params_from_app(keyword, String.t(), String.t()) :: keyword
  defp complete_params_from_app(params, oidc_provider, provider_url) do
    app =
      %{client_name: App.get_provider(provider_url), provider: "oidc_#{oidc_provider}"}
      |> App.get_by()

    Keyword.merge(params,
      client_id: app.client_id,
      client_secret: app.client_secret,
      redirect_uri: app.redirect_uris |> List.wrap() |> List.first()
    )
  end

  @spec complete_params_from_config(keyword, String.t()) :: keyword
  defp complete_params_from_config(params, oidc_provider) do
    config_opts = Config.oidc_provider_opts(oidc_provider)

    Keyword.merge(params,
      client_id: config_opts[:client_id],
      client_secret: config_opts[:client_secret]
    )
  end

  # Strategy Callbacks

  @spec authorize_url(Client.t(), map) :: Client.t()
  def authorize_url(client, params) do
    Strategy.AuthCode.authorize_url(client, params)
  end

  @spec get_token(Client.t(), keyword, keyword) :: Client.t()
  def get_token(client, params, headers) do
    client
    |> put_param("client_secret", client.client_secret)
    |> put_header("Accept", "application/json")
    |> Strategy.AuthCode.get_token(params, headers)
  end
end
