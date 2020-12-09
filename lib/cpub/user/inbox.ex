# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.User.Inbox do
  @moduledoc """
  A `CPub.User`s inbox.
  """
  alias CPub.DMC.Set
  alias CPub.Signify
  alias CPub.User

  def get(%User{} = user) do
    Set.state(user.inbox)
  end

  def put(%User{} = user, message) do
    with {:ok, message_read_cap} <- ERIS.ReadCapability.parse(message),
         {:ok, add_op} <- Set.Add.new(user.inbox.id, message_read_cap),
         {:ok, signature} <- Signify.sign(add_op.id, user.inbox_secret_key),
         {:ok, _} <- Signify.Signature.insert(signature) do
      :ok
    end
  end
end
