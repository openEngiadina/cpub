# SPDX-FileCopyrightText: 2020, 2021 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.User.Inbox do
  @moduledoc """
  A `CPub.User`s inbox.
  """
  alias CPub.DB
  alias CPub.User

  def get(%User{} = user) do
    DB.Set.state(user.inbox)
  end

  def put(%User{} = user, message) do
    with {:ok, message_read_cap} <- ERIS.ReadCapability.parse(message),
         :ok <- DB.Set.add(user.inbox, message_read_cap) do
      :ok
    end
  end
end
