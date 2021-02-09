# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.HTTP do
  @moduledoc """
  Wrapper for `Tesla.request/2`.
  """

  alias CPub.HTTP.AdapterHelper
  alias CPub.HTTP.Request
  alias CPub.HTTP.RequestBuilder, as: Builder

  alias Tesla.Client
  alias Tesla.Env

  @type t :: __MODULE__

  @doc """
  Performs GET HTTP request.
  """
  @spec get(Request.url() | nil, Request.headers(), keyword) ::
          nil | {:ok, Env.t()} | {:error, any}
  def get(url, headers \\ [], options \\ [])
  def get(nil, _, _), do: nil
  def get(url, headers, options), do: request(:get, url, "", headers, options)

  @doc """
  Performs HEAD HTTP request.
  """
  @spec head(Request.url(), Request.headers(), keyword) :: {:ok, Env.t()} | {:error, any}
  def head(url, headers \\ [], options \\ []), do: request(:head, url, "", headers, options)

  @doc """
  Performs POST HTTP request.
  """
  @spec post(Request.url(), String.t(), Request.headers(), keyword) ::
          {:ok, Env.t()} | {:error, any}
  def post(url, body, headers \\ [], options \\ []) do
    request(:post, url, body, headers, options)
  end

  @doc """
  Builds and performs HTTP request.
  """
  @spec request(Request.method(), Request.url(), String.t(), Request.headers(), keyword) ::
          {:ok, Env.t()} | {:error, any}
  def request(method, url, body, headers, options) when is_binary(url) do
    uri = URI.parse(url)
    adapter_opts = AdapterHelper.options(uri, options || [])

    options = put_in(options[:adapter], adapter_opts)
    params = options[:params] || []
    request = build_request(method, headers, options, url, body, params)

    adapter = Application.get_env(:tesla, :adapter)

    client = Tesla.client(adapter_middlewares(adapter), adapter)

    maybe_limit(fn -> request(client, request) end, adapter, adapter_opts)
  end

  @spec request(Client.t(), keyword) :: {:ok, Env.t()} | {:error, any}
  def request(client, request), do: Tesla.request(client, request)

  defp build_request(method, headers, options, url, body, params) do
    Builder.new()
    |> Builder.method(method)
    |> Builder.headers(headers)
    |> Builder.opts(options)
    |> Builder.url(url)
    |> Builder.add_param(:body, :body, body)
    |> Builder.add_param(:query, :query, params)
    |> Builder.convert_to_keyword()
  end

  defp adapter_middlewares(Tesla.Adapter.Gun) do
    [Tesla.Middleware.FollowRedirects, CPub.HTTP.Tesla.Middleware.ConnectionPool]
  end

  defp adapter_middlewares(_), do: []

  @pool CPub.HTTP.Gun.ConnectionPool
  defp maybe_limit(fun, Tesla.Adapter.Gun, opts) do
    ConcurrentLimiter.limit(:"#{@pool}.#{opts[:pool] || :default}", fun)
  end

  defp maybe_limit(fun, _, _), do: fun.()
end
