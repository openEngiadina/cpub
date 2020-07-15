defmodule Ueberauth.Strategy.Pleroma.OAuth do
  @moduledoc """
  An implementation of OAuth2 for Pleroma/Mastodon compatible providers.
  """

  use OAuth2.Strategy

  alias OAuth2.{Client, Strategy}

  @doc """
  Constructs a client for requests to Pleroma/Mastodon compatible providers.
  """
  @spec client(keyword) :: Client.t()
  def client(opts) do
    [strategy: __MODULE__]
    |> Keyword.merge(opts)
    |> Client.new()
    |> Client.put_serializer("application/json", Jason)
  end

  # Strategy Callbacks

  @spec authorize_url(Client.t(), map) :: Client.t()
  def authorize_url(client, params) do
    Strategy.AuthCode.authorize_url(client, params)
  end

  @spec get_token(Client.t(), keyword, keyword) :: Client.t()
  def get_token(client, params, headers) do
    with client_token <-
           client
           |> put_param("client_secret", client.client_secret)
           |> put_header("Accept", "application/json")
           |> Strategy.AuthCode.get_token(params, headers) do
      client_token
    end
  end
end
