# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.OAuthRequest do
  @moduledoc """
  Replacement for `OAuth2.Request` which uses `CPub.HTTP` to make requests.
  """

  import OAuth2.Util

  alias CPub.HTTP

  alias OAuth2.{AccessToken, Client, Error, Response}

  require Logger

  @doc """
  Makes a request of given type to the given URL using the `OAuth2.AccessToken`.
  """
  @spec request(atom, Client.t(), String.t(), any, Client.headers(), keyword) ::
          {:ok, Response.t()} | {:ok, reference} | {:error, Response.t()} | {:error, Error.t()}
  def request(method, %Client{} = client, url, body \\ "", headers \\ [], opts \\ []) do
    url = client |> process_url(url) |> process_params(opts[:params])
    req_headers = req_headers(client, headers) |> Enum.uniq()
    content_type = content_type(headers)
    serializer = Client.get_serializer(client, content_type)
    req_body = encode_request_body(body, content_type, serializer)
    req_headers = process_request_headers(req_headers, content_type)
    req_opts = Keyword.merge(client.request_opts, opts)

    if Application.get_env(:oauth2, :debug) do
      Logger.debug("""
        OAuth2 Provider Request (CPub)
        url: #{inspect(url)}
        method: #{inspect(method)}
        headers: #{inspect(req_headers)}
        body: #{inspect(req_body)}
        req_opts: #{inspect(req_opts)}
      """)
    end

    case HTTP.request(method, url, req_body, req_headers, req_opts) do
      {:ok, %{status: status, headers: resp_headers, body: resp_body}} ->
        process_body(client, status, resp_headers, resp_body)

      {:error, reason} ->
        {:error, %Error{reason: reason}}
    end
  end

  @doc """
  Same as `request/6` but returns `OAuth2.Response` or raises an error if an
  error occurs during the request.

  An `OAuth2.Error` exception is raised if the request results in an
  error tuple (`{:error, reason}`).
  """
  @spec request!(atom, Client.t(), String.t(), any, Client.headers(), keyword) :: Response.t()
  def request!(method, %Client{} = client, url, body, headers, opts) do
    case request(method, client, url, body, headers, opts) do
      {:ok, response} ->
        response

      {:error, %Response{status_code: code, headers: headers, body: body}} ->
        raise %Error{
          reason: """
          Server responded with status: #{code}
          Headers:
          #{Enum.reduce(headers, "", fn {k, v}, acc -> acc <> "#{k}: #{v}\n" end)}
          Body:
          #{inspect(body)}
          """
        }

      {:error, error} ->
        raise error
    end
  end

  @spec process_body(Client.t(), non_neg_integer, Client.headers(), any) ::
          {:ok, Response.t()} | {:error, Response.t()}
  defp process_body(client, status, headers, body) when is_binary(body) do
    response = Response.new(client, status, headers, body)

    case status do
      status when status in 200..399 -> {:ok, response}
      status when status in 400..599 -> {:error, response}
    end
  end

  @spec process_url(Client.t(), String.t()) :: String.t()
  defp process_url(client, url) do
    case String.downcase(url) do
      <<"http://"::utf8, _::binary>> -> url
      <<"https://"::utf8, _::binary>> -> url
      _ -> "#{client.site}#{url}"
    end
  end

  @spec process_params(String.t(), map | nil) :: String.t()
  defp process_params(url, nil), do: url
  defp process_params(url, params), do: "#{url}?#{URI.encode_query(params)}"

  @spec req_headers(Client.t(), Client.headers()) :: Client.headers()
  defp req_headers(%Client{token: nil} = client, headers), do: headers ++ client.headers

  defp req_headers(%Client{token: token} = client, headers) do
    [authorization_header(token) | headers] ++ client.headers
  end

  @spec authorization_header(AccessToken.t()) :: {String.t(), String.t()}
  defp authorization_header(token) do
    {"authorization", "#{token.token_type} #{token.access_token}"}
  end

  @spec encode_request_body(any, String.t(), module | nil) :: String.t()
  defp encode_request_body("", _, _), do: ""
  defp encode_request_body([], _, _), do: ""

  defp encode_request_body(body, "application/x-www-form-urlencoded", _) do
    URI.encode_query(body)
  end

  defp encode_request_body(body, _mime, nil), do: body
  defp encode_request_body(body, _mime, serializer), do: serializer.encode!(body)

  @spec process_request_headers(Client.headers(), String.t()) :: Client.headers()
  defp process_request_headers(headers, content_type) do
    case List.keyfind(headers, "accept", 0) do
      {"accept", _} -> headers
      nil -> [{"accept", content_type} | headers]
    end
  end
end
