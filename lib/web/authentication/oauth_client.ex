# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.OAuthClient do
  @moduledoc """
  An OAuth 2.0 client that is used by CPub to authenticate with an external
  provider.

  See `CPub.Web.Authorization.Client` for OAuth 2.0 clients for receving
  authorization to access resources on CPub.
  """

  alias CPub.DB

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
  def get(site) do
    DB.transaction(fn ->
      case Memento.Query.read(__MODULE__, site) do
        nil ->
          DB.abort(:not_found)

        client ->
          client
      end
    end)
  end

  @doc """
  Returns list of Clients with display name
  """
  def get_displayable do
    DB.transaction(fn ->
      Memento.Query.select(__MODULE__, {:!=, :display_name, nil})
    end)
  end
end
