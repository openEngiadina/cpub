# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authorization.ClientController do
  @moduledoc """
  Controller that handles OAuth 2.0 client registration.

  See also [RFC 7591: OAuth 2.0 Dynamic Client Registration Protocol](https://tools.ietf.org/html/rfc7591)
  """

  use CPub.Web, :controller

  alias CPub.Web.Authorization.Client

  action_fallback CPub.Web.Authorization.FallbackController

  @doc """
  Create a new OAuth 2.0 client
  """
  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(%Plug.Conn{body_params: body} = conn, _params) do
    attrs =
      body
      |> Map.take(["client_name"])
      |> Map.put("redirect_uris", List.wrap(body["redirect_uris"]))
      |> Map.put("scope", body["scope"] || body["scopes"])

    with {:ok, client} <- Client.create(attrs) do
      conn
      |> put_status(:created)
      |> put_view(JSONView)
      |> render(:show,
        data: %{
          client_name: client.client_name,
          client_id: client.id,
          client_secret: client.client_secret,
          redirect_uris: client.redirect_uris,
          scope: client.scope |> Enum.join(" ")
        }
      )
    end
  end
end
