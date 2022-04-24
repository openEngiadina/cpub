# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.UserTest do
  use ExUnit.Case
  use CPub.DataCase

  alias CPub.User

  doctest CPub.User

  describe "create/1" do
    test "creates a new user" do
      assert {:ok, _user} = User.create("alice")
    end

    test "disallows username reuse" do
      assert {:ok, _user} = User.create("alice")
      assert {:error, _} = User.create("alice")
    end
  end
end
