defmodule CPub.Web.OAuth.Strategy.WebIDOIDC.OAuth do
  @moduledoc """
  An implementation of OAuth2 for WebID-OIDC (Solid) compatible providers.
  """

  use OAuth2.Strategy

  alias CPub.Web.HTTP
  alias CPub.Web.OAuth.App
  alias CPub.Web.OAuth.Strategy.{Utils, WebIDOIDC}

  alias OAuth2.{AccessToken, Client, Strategy}

  @doc """
  Constructs a client for requests to WebID-OIDC compatible providers.
  """
  @spec client(keyword) :: Client.t()
  def client(opts) do
    site = opts[:state]
    app = App.get_by(%{client_name: App.get_provider(site), provider: WebIDOIDC.provider()})

    authorize_url = HTTP.merge_uri(site, app.metadata["authorization_endpoint"])
    token_url = HTTP.merge_uri(site, app.metadata["token_endpoint"])

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

  @spec get(AccessToken.t()) :: {:ok, RDF.Graph.t()} | {:error, any}
  def get(%AccessToken{other_params: %{"id_token" => id_token, "provider_url" => provider_url}}) do
    app =
      %{client_name: App.get_provider(provider_url), provider: WebIDOIDC.provider()}
      |> App.get_by()

    with {:ok, web_id} <- derive_web_id(id_token, provider_url),
         {:ok, body, _} <- HTTP.request(:get, web_id, %{}, [{"Accept", "text/turtle"}]) do
      case RDF.Turtle.Decoder.decode(body, base_iri: "#{app.metadata["issuer"]}/") do
        {:ok, user} ->
          case issuer_confirmed?(id_token, web_id, user) do
            true -> {:ok, user}
            false -> {:error, :unauthorized_issuer}
          end

        {:error, _} ->
          RDF.JSON.Decoder.decode(body)
      end
    end
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
    app =
      %{client_name: App.get_provider(provider_url), provider: WebIDOIDC.provider()}
      |> App.get_by()

    Keyword.merge(params,
      client_id: app.client_id,
      client_secret: app.client_secret,
      redirect_uri: app.redirect_uris |> List.wrap() |> List.first()
    )
  end

  @spec derive_web_id(String.t(), String.t()) :: {:ok, String.t()} | {:error, any}
  defp derive_web_id(id_token, provider_url) do
    app =
      %{client_name: App.get_provider(provider_url), provider: WebIDOIDC.provider()}
      |> App.get_by()

    with {:ok, claims} <- Joken.peek_claims(id_token),
         :userinfo <- claims["webid"] || claims["sub"] || :userinfo,
         {:ok, body, _} <- HTTP.request(:get, app.metadata["userinfo_endpoint"]),
         {:ok, userinfo} <- Jason.decode(body) do
      {:ok, userinfo["website"]}
    else
      web_id when is_binary(web_id) ->
        {:ok, web_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec issuer_confirmed?(String.t(), String.t(), RDF.Graph.t()) :: boolean
  defp issuer_confirmed?(id_token, web_id, user) do
    # https://github.com/solid/webid-oidc-spec/blob/master/README.md#webid-provider-confirmation
    {:ok, claims} = Joken.peek_claims(id_token)
    [web_id_domian, issuer_domain] = Enum.map([web_id, claims["iss"]], &App.get_provider/1)

    String.ends_with?(web_id_domian, issuer_domain) ||
      case Utils.discover_issuer_from_headers(web_id) do
        {:ok, issuer} -> issuer == claims["iss"]
        {:error, _} -> Utils.fetch_issuer_from_web_id_profile(user) == claims["iss"]
      end
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
