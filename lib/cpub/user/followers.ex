# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.User.Followers do
  @moduledoc """
  A `CPub.User`s followers.
  """

  alias CPub.DB
  alias CPub.User

  @spec get(User.t()) :: {:ok, MapSet.t()} | {:error, any}
  def get(%User{} = user) do
    DB.Set.state(user.followers)
  end
end
