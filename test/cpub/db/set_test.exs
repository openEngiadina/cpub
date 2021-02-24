# SPDX-FileCopyrightText: 2021 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.DB.SetTest do
  use ExUnit.Case
  use CPub.RDFCase

  alias CPub.DB

  doctest CPub.DB.Set

  describe "new/0" do
    test "Returns a new identifier for an empty set" do
      id = DB.Set.new()

      {:ok, set} = DB.Set.state(id)
      assert MapSet.size(set) == 0
    end
  end

  describe "add/2" do
    test "Add elements to set" do
      id = DB.Set.new()

      {:ok, empty_set} = DB.Set.state(id)
      assert MapSet.size(empty_set) == 0

      :ok = DB.Set.add(id, "hello")
      {:ok, set1} = DB.Set.state(id)
      assert MapSet.size(set1) == 1

      :ok = DB.Set.add(id, "hello")
      {:ok, set2} = DB.Set.state(id)
      assert MapSet.size(set2) == 1

      :ok = DB.Set.add(id, "mnesia!")
      {:ok, set3} = DB.Set.state(id)
      assert MapSet.size(set3) == 2
    end
  end

  describe "remove/2" do
    test "Remove an element" do
      id = DB.Set.new()

      {:ok, empty_set} = DB.Set.state(id)
      assert MapSet.size(empty_set) == 0

      :ok = DB.Set.add(id, "hello")
      {:ok, set1} = DB.Set.state(id)
      assert MapSet.size(set1) == 1

      :ok = DB.Set.remove(id, "hello")
      {:ok, set2} = DB.Set.state(id)
      assert MapSet.size(set2) == 0
    end
  end
end
