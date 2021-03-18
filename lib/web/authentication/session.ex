# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.Session do
  @moduledoc """
  A `CPub.Web.Authentication.Session` is used for handling authentication with CPub.

  An authenticated `CPub.User` has a session stored in the `Plug.Session` storage.

  A session does not grant access to any resources. Access is granted with a
  `CPub.Web.Authorization`.
  """

  alias CPub.DB
  alias CPub.User

  use Memento.Table,
    attributes: [:id, :user, :last_activity],
    index: [:user],
    type: :set

  @doc """
  Create a new session for a user.
  """
  def create(%User{} = user) do
    DB.transaction(fn ->
      %__MODULE__{
        id: UUID.uuid4(),
        user: user.id,
        last_activity: DateTime.utc_now()
      }
      |> Memento.Query.write()
    end)
  end

  @doc """
  Get a session by id.
  """
  def get_by_id(id) do
    DB.transaction(fn ->
      Memento.Query.read(__MODULE__, id)
    end)
  end

  @doc """
  Delete a session.
  """
  def delete(id) do
    DB.transaction(fn ->
      Memento.Query.delete(__MODULE__, id)
    end)
  end
end
