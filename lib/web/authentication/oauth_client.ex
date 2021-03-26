# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.OAuthClient do
  @moduledoc """
  An OAuth 2.0 client that is used by CPub to authenticate with an external
  provider. Replaces some functions of `OAuth2.Client` which uses `CPub.HTTP`
  to make requests.

  See `CPub.Web.Authorization.Client` for OAuth 2.0 clients for receving
  authorization to access resources on CPub.
  """

  use Memento.Table,
    attributes: [
      # The site of the identity provider (in OIDC lingo: issuer)
      :site,

      # The provider type (either :mastodon or :oidc)
      :provider,

      # client id and secret
      :client_id,
      :client_secret,

      # name to display in Authentication UI
      :display_name
    ],
    type: :set

  alias CPub.DB
  alias CPub.Web.Authentication.OAuthRequest

  alias OAuth2.{AccessToken, Client, Error, Response}

  @type t :: %__MODULE__{
          site: String.t(),
          provider: String.t(),
          client_id: String.t(),
          client_secret: String.t(),
          display_name: String.t()
        }

  @spec create(map) :: {:ok, t} | {:error, any}
  def create(attrs) do
    DB.transaction(fn ->
      %__MODULE__{
        site: attrs.site,
        provider: attrs.provider,
        client_id: attrs.client_id,
        client_secret: Map.get(attrs, :client_secret),
        display_name: Map.get(attrs, :display_name)
      }
      |> Memento.Query.write()
    end)
  end

  @doc """
  Get the `OAuthClient` for the given site.
  """
  @spec get(String.t()) :: {:ok, t} | {:error, any}
  def get(site) do
    DB.transaction(fn ->
      case Memento.Query.read(__MODULE__, site) do
        nil ->
          _ = DB.abort(:not_found)

        client ->
          client
      end
    end)
  end

  @doc """
  Returns list of Clients with display name.
  """
  @spec get_displayable :: {:ok, [t]} | {:error, any}
  def get_displayable do
    DB.transaction(fn ->
      Memento.Query.select(__MODULE__, {:!=, :display_name, nil})
    end)
  end

  @doc """
  Replaces `OAuth2.Client.get_token/4` and uses `CPub.HTTP` to make requests.
  """
  @spec get_token(Client.t(), Client.params(), Client.headers(), keyword) ::
          {:ok, Client.t()} | {:error, Response.t()} | {:error, Error.t()}
  def get_token(%{token_method: method} = client, params \\ [], headers \\ [], opts \\ []) do
    {client, url} = token_url(client, params, headers)

    case OAuthRequest.request(method, client, url, client.params, client.headers, opts) do
      {:ok, response} ->
        {:ok, %{client | headers: [], params: %{}, token: AccessToken.new(response.body)}}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec token_url(Client.t(), Client.params(), Client.headers()) :: {Client.t(), String.t()}
  defp token_url(client, params, headers) do
    client
    |> token_post_header()
    |> client.strategy.get_token(params, headers)
    |> to_url(:token_url)
  end

  @spec token_post_header(Client.t()) :: Client.t()
  defp token_post_header(%Client{token_method: :post} = client) do
    Client.put_header(client, "content-type", "application/x-www-form-urlencoded")
  end

  defp token_post_header(%Client{} = client), do: client

  @spec to_url(Client.t(), atom | String.t()) :: {Client.t(), String.t()}
  defp to_url(%Client{token_method: :post} = client, :token_url) do
    {client, endpoint(client, client.token_url)}
  end

  defp to_url(client, endpoint) do
    endpoint = Map.get(client, endpoint)
    url = "#{endpoint(client, endpoint)}?#{URI.encode_query(client.params)}"

    {client, url}
  end

  @spec endpoint(Client.t(), String.t()) :: String.t()
  defp endpoint(client, <<"/"::utf8, _::binary>> = endpoint), do: "#{client.site}#{endpoint}"
  defp endpoint(_client, endpoint), do: endpoint
end
