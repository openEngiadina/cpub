# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authorization.FallbackController do
  @moduledoc """
  Error handler for OAuth 2.0 Authorization Server.

  See also https://tools.ietf.org/html/rfc6749#section-4.1.2.1 and https://tools.ietf.org/html/rfc6749#section-4.2.2.1
  """

  use CPub.Web, :controller

  import CPub.Web.Authorization.Utils

  @doc """
  Redirect connection to redirect_uri with error code and description
  """
  def call(
        %Plug.Conn{} = conn,
        {:error, code, description}
      ) do
    with %{oauth_redirect_on_error: true} <- conn.assigns,
         {:ok, client} <- get_client(conn),
         {:ok, redirect_uri} <- get_redirect_uri(conn, client),
         {:ok, state} <- get_state(conn) do
      cb_uri =
        redirect_uri
        |> Map.put(
          :query,
          URI.encode_query(%{
            error: code,
            error_description: description,
            state: state
          })
        )
        |> URI.to_string()

      conn
      |> redirect(external: cb_uri)
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: code, error_description: description})
    end
  end

  def call(%Plug.Conn{} = conn, {:error, reason}) do
    call(conn, {:error, :bad_request, reason})
  end
end
