defmodule OAuth2.Strategy.PublicAuthCode do
  @moduledoc """
  The Authorization Code Strategy that does not use BasicAuth when there is no client_secret set.

  See also: https://github.com/scrogson/oauth2/issues/142
  """

  use OAuth2.Strategy

  alias OAuth2.Client

  @doc """
  The authorization URL endpoint of the provider.
  params additional query parameters for the URL
  """
  @impl true
  def authorize_url(client, params) do
    client
    |> put_param(:response_type, "code")
    |> put_param(:client_id, client.client_id)
    |> put_param(:redirect_uri, client.redirect_uri)
    |> merge_params(params)
  end

  @doc """
  Retrieve an access token given the specified validation code.
  """
  @impl true
  def get_token(%Client{client_secret: nil} = client, params, headers) do
    {code, params} = Keyword.pop(params, :code, client.params["code"])

    unless code do
      raise OAuth2.Error, reason: "Missing required key `code` for `#{inspect(__MODULE__)}`"
    end

    client
    |> put_param(:code, code)
    |> put_param(:grant_type, "authorization_code")
    |> put_param(:client_id, client.client_id)
    |> put_param(:redirect_uri, client.redirect_uri)
    |> merge_params(params)
    |> put_headers(headers)
  end

  def get_token(client, params, headers) do
    {code, params} = Keyword.pop(params, :code, client.params["code"])

    unless code do
      raise OAuth2.Error, reason: "Missing required key `code` for `#{inspect(__MODULE__)}`"
    end

    client
    |> put_param(:code, code)
    |> put_param(:grant_type, "authorization_code")
    |> put_param(:client_id, client.client_id)
    |> put_param(:redirect_uri, client.redirect_uri)
    |> merge_params(params)
    |> basic_auth()
    |> put_headers(headers)
  end
end
