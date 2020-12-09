# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.DMC.SetTest do
  use ExUnit.Case
  use CPub.RDFCase

  alias CPub.DMC
  alias CPub.DMC.Set
  alias CPub.Signify

  doctest CPub.DMC.Set

  describe "new/1" do
    test "create a new Set definition" do
      secret_key = Signify.SecretKey.generate()
      {:ok, set} = Set.new(secret_key.public_key)

      assert {:ok, set_definition} = DMC.Definition.get(set.id)
      assert set_definition.id === set.id

      assert set_definition.root_public_key === secret_key.public_key
    end
  end

  describe "state/1" do
    test "adds without signatures are ignored" do
      secret_key = Signify.SecretKey.generate()
      {:ok, set} = Set.new(secret_key.public_key)

      element = ERIS.encode_urn("Hello world!")
      assert {:ok, add_op} = Set.Add.new(set.id, element)

      assert {:ok, state} = Set.state(set)
      assert MapSet.size(state) === 0
    end

    test "add single element" do
      secret_key = Signify.SecretKey.generate()
      {:ok, set} = Set.new(secret_key.public_key)

      element = ERIS.encode_read_capability("Hello world!")
      assert {:ok, add_op} = Set.Add.new(set.id, element)
      assert {:ok, signature} = Signify.sign(add_op.id, secret_key)
      assert {:ok, _} = Signify.Signature.insert(signature)

      assert {:ok, state} = Set.state(set)
      assert MapSet.member?(state, element)
      assert MapSet.size(state) === 1
    end

    test "add and remove single element" do
      secret_key = Signify.SecretKey.generate()
      {:ok, set} = Set.new(secret_key.public_key)

      element = ERIS.encode_read_capability("Hello world!")
      assert {:ok, add_op} = Set.Add.new(set.id, element)
      assert {:ok, signature} = Signify.sign(add_op.id, secret_key)
      assert {:ok, _} = Signify.Signature.insert(signature)

      assert {:ok, remove_op} = Set.Remove.new(set.id, add_op.id)
      assert {:ok, remove_signature} = Signify.sign(remove_op.id, secret_key)
      assert {:ok, _} = Signify.Signature.insert(remove_signature)

      assert {:ok, state} = Set.state(set.id)
      assert MapSet.size(state) === 0
    end
  end
end
