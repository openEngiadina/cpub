# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authorization.Utils do
  @moduledoc """
  Helpers and utils for dealing with OAuth 2.0 Endpoint requests.
  """

  alias CPub.Web.Authorization.Client
  alias CPub.Web.Authorization.Scope

  @doc """
  Returns the `CPub.Web.Authorization.Client` associated with the connection.
  """
  @spec get_client(Plug.Conn.t()) :: {:ok, Client.t()} | {:error, any, any}
  def get_client(%Plug.Conn{} = conn) do
    with {client_id, _} when is_binary(client_id) <- get_client_credentials(conn),
         {:ok, %Client{} = client} <- Client.get(client_id) do
      {:ok, client}
    else
      _ ->
        {:error, :invalid_request, "invalid client_id"}
    end
  end

  @spec get_client_credentials(Plug.Conn.t()) :: {String.t(), String.t()}
  def get_client_credentials(%Plug.Conn{} = conn) do
    # Per RFC 6749, HTTP Basic is preferred to body params
    with ["Basic " <> encoded] <- Plug.Conn.get_req_header(conn, "authorization"),
         {:ok, decoded} <- Base.decode64(encoded),
         [id, secret] <- Enum.map(String.split(decoded, ":"), &URI.decode_www_form/1) do
      {id, secret}
    else
      _ -> {conn.params["client_id"], conn.params["client_secret"]}
    end
  end

  @doc """
  Returns a valid redirect_uri for given connection and client/authorization.
  """
  @spec get_redirect_uri(Plug.Conn.t(), Client.t()) :: {:ok, URI.t()} | {:error, any, any}
  def get_redirect_uri(%Plug.Conn{} = conn, %Client{} = client) do
    case Client.get_redirect_uri(client, conn.params) do
      {:ok, redirect_uri} ->
        {:ok, redirect_uri}

      :error ->
        {:error, :invalid_request, "redirect_uri not valid or not allowed for client."}
    end
  end

  @doc """
  Returns a valid scope for given connection and client
  """
  @spec get_scope(Plug.Conn.t(), Client.t()) :: {:ok, [atom]} | {:error, any, any}
  def get_scope(%Plug.Conn{} = conn, %Client{} = client) do
    with {:ok, scope} <- Scope.parse(Access.get(conn.params, "scope", Scope.default())),
         true <- Scope.scope_subset?(scope, client.scope) do
      {:ok, scope}
    else
      _ ->
        {:error, :invalid_request, "scope not valid or not allowed for client."}
    end
  end

  @doc """
  Returns OAuth 2.0 request state from connection
  """
  @spec get_state(Plug.Conn.t()) :: {:ok, String.t()}
  def get_state(%Plug.Conn{} = conn) do
    {:ok, conn.params["state"]}
  end
end
