# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authorization.AuthorizationPlug do
  @moduledoc """
  Plug that assigns a `CPub.Web.Authorization` to the connection
  if valid access token is found in headers.

  Note that routes that require authorization still need to manually check if
  the authorization assigned in the connection by this plug is valid for the
  ressource being accessed.
  """

  use Phoenix.Controller, namespace: CPub.Web

  import Plug.Conn

  alias CPub.Web.Authorization

  def init(opts), do: opts

  def call(%Plug.Conn{} = conn, _opts) do
    case fetch_token_from_header(conn) do
      {:ok, access_token} ->
        with {:ok, token} <- Authorization.Token.get(access_token),
             {:ok, authorization} <- Authorization.get(token.authorization),
             false <- Authorization.Token.expired?(token) do
          conn
          |> assign(:authorization, authorization)
        else
          _ ->
            # If token is invalid or expired then halt the connection and display error
            conn
            |> put_status(:unauthorized)
            |> text("Unauthorized")
            |> halt
        end

      :no_token_found ->
        # If there is no token, continue without assigning authorization
        conn
    end
  end

  # Get token from headers (code from Pleroma)

  @realm_reg Regex.compile!("Bearer\:?\s+(.*)$", "i")

  @spec fetch_token_from_header(Plug.Conn.t()) :: :no_token_found | {:ok, String.t()}
  defp fetch_token_from_header(%Plug.Conn{} = conn) do
    conn
    |> get_req_header("authorization")
    |> fetch_token_str()
  end

  @spec fetch_token_str(Keyword.t()) :: :no_token_found | {:ok, String.t()}
  defp fetch_token_str([]), do: :no_token_found

  defp fetch_token_str([token | tail]) do
    trimmed_token = String.trim(token)

    case Regex.run(@realm_reg, trimmed_token) do
      [_, match] -> {:ok, String.trim(match)}
      _ -> fetch_token_str(tail)
    end
  end
end
