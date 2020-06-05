defmodule CPub.Web.OAuth.Strategy.Pleroma.OAuth do
  @moduledoc """
  An implementation of OAuth2 for Pleroma/Mastodon compatible providers.
  """

  use OAuth2.Strategy

  alias CPub.Web.OAuth.App
  alias CPub.Web.OAuth.Strategy.{Pleroma, Utils}

  alias OAuth2.{AccessToken, Client, Response, Strategy}

  @authorize_url_endpoint "/oauth/authorize"
  @token_endpoint "/oauth/token"

  @doc """
  Constructs a client for requests to Pleroma/Mastodon compatible providers.
  """
  @spec client(keyword) :: Client.t()
  def client(opts) do
    site = opts[:state]
    authorize_url = Utils.merge_uri(site, @authorize_url_endpoint)
    token_url = Utils.merge_uri(site, @token_endpoint)

    [strategy: __MODULE__, site: site, authorize_url: authorize_url, token_url: token_url]
    |> Keyword.merge(opts)
    |> Client.new()
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

  @spec get(AccessToken.t(), String.t(), keyword, keyword) ::
          {:ok, Response.t()} | {:error, any}
  def get(
        %AccessToken{other_params: %{"provider_url" => provider_url}} = token,
        url,
        headers \\ [],
        opts \\ []
      ) do
    [token: token, state: provider_url]
    |> complete_params_from_app(provider_url)
    |> client()
    |> Client.get(url, headers, opts)
  end

  @spec get_token!(keyword, keyword) :: AccessToken.t()
  def get_token!(params \\ [], options \\ []) do
    headers = Keyword.get(options, :headers, [])
    options = Keyword.get(options, :options, [])
    provider_url = Keyword.get(params, :state)

    params = complete_params_from_app(params, provider_url)
    client = Client.get_token!(client(params), params, headers, options)

    client.token
  end

  @spec complete_params_from_app(keyword, String.t()) :: keyword
  defp complete_params_from_app(params, provider_url) do
    app = App.get_by(%{client_name: App.get_provider(provider_url), provider: Pleroma.provider()})

    Keyword.merge(params,
      client_id: app.client_id,
      client_secret: app.client_secret,
      redirect_uri: app.redirect_uris |> List.wrap() |> List.first()
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
