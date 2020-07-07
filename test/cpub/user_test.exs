defmodule CPub.UserTest do
  use ExUnit.Case
  use CPub.DataCase

  alias CPub.User
  alias CPub.Object

  doctest CPub.User

  describe "create/1" do
    test "creates a new user" do
      assert {:ok, user} = User.create(%{username: "alice", password: "123"})
    end

    test "disallows username reuse" do
      assert {:ok, user} = User.create(%{username: "alice", password: "123"})
      assert {:error, _} = User.create(%{username: "alice", password: "123"})
    end
  end
end
