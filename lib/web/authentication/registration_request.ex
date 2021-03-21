# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.RegistrationRequest do
  @moduledoc """
  A request to register with an external identiy provider.

  This is a temporary entitiy that only exists while the user has authenticated
  with external provider but not created an associated local user yet.
  """

  use Memento.Table,
    attributes: [:id, :provider, :site, :external_id, :username],
    type: :set

  alias CPub.DB

  @type t :: %__MODULE__{
          id: String.t(),
          provider: String.t(),
          site: String.t(),
          external_id: String.t(),
          username: String.t()
        }

  @spec create(String.t(), String.t(), String.t(), String.t()) :: {:ok, t} | {:error, any}
  def create(site, provider, external_id, username) do
    DB.transaction(fn ->
      %__MODULE__{
        id: UUID.uuid4(),
        provider: provider,
        site: site,
        external_id: external_id,
        username: username
      }
      |> Memento.Query.write()
    end)
  end

  @spec get(String.t()) :: {:ok, t} | {:error, any}
  def get(id) do
    DB.transaction(fn ->
      Memento.Query.read(__MODULE__, id)
    end)
  end
end
