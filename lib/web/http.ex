# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.HTTP do
  @moduledoc """
  Functions related to HTTP.
  """

  @type body :: String.t()
  @type header :: {String.t(), String.t()}

  @spec request(atom, String.t(), map, [header]) :: {:ok, body, [header]} | {:error, any}
  def request(method, url, body \\ %{}, headers \\ [{"Content-Type", "application/json"}]) do
    body = Jason.encode!(body)
    response = :hackney.request(method, url, headers, body, [])

    with true <- is_valid_url(url),
         {:ok, _resp_code, headers, client} <- response,
         {:ok, body} <- :hackney.body(client) do
      {:ok, body, headers}
    else
      false ->
        {:error, :invalid_url}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec is_valid_url(String.t()) :: boolean
  def is_valid_url(provider_url) do
    with uri <- URI.parse(provider_url), do: !!(uri.scheme && uri.host)
  end

  @spec merge_uri(String.t(), String.t()) :: String.t()
  def merge_uri(site, endpoint) do
    site
    |> URI.merge(endpoint)
    |> URI.to_string()
  end
end
