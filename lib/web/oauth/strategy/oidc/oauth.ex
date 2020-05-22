defmodule CPub.Web.OAuth.Strategy.OIDC.OAuth do
  @moduledoc """
  An implementation of OAuth2 for OpenID Connect compatible providers.
  """

  use OAuth2.Strategy

  alias CPub.Config

  alias OAuth2.{AccessToken, Client, Response, Strategy}

  @doc """
  Construct a client for requests to Github.

  Optionally include any OAuth2 options here to be merged with the defaults.

  This will be setup automatically for you in `CPub.Web.OAuth.Strategy.OIDC`.
  These options are only useful for usage outside the normal callback phase of
  Ueberauth.
  """
  @spec client(keyword) :: Client.t()
  def client(opts \\ []) do
    [strategy: __MODULE__]
    |> Keyword.merge(Config.oidc_provider_opts(opts[:provider] || opts[:state]))
    |> Keyword.merge(Keyword.delete(opts, :provider))
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

  @spec get(AccessToken.t(), keyword, keyword) :: {:ok, Response.t()} | {:error, any}
  def get(
        %AccessToken{other_params: %{"provider" => oidc_provider}} = token,
        headers \\ [],
        opts \\ []
      ) do
    url = Config.oidc_provider_opts(oidc_provider)[:userinfo_url]

    [token: token, state: oidc_provider]
    |> complete_params_from_config(oidc_provider)
    |> client()
    |> Client.get(url, headers, opts)
  end

  @spec get_token!(keyword, keyword) :: AccessToken.t()
  def get_token!(params \\ [], options \\ []) do
    headers = Keyword.get(options, :headers, [])
    options = Keyword.get(options, :options, [])
    oidc_provider = Keyword.get(params, :state)
    params = complete_params_from_config(params, oidc_provider)

    client = Client.get_token!(client(params), params, headers, options)

    client.token
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
