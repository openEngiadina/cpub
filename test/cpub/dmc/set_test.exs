# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.DMC.SetTest do
  use ExUnit.Case
  use CPub.RDFCase

  doctest CPub.DMC.Set

  describe "new/1" do
    test "create a new Set definition" do
      secret_key = CPub.Signify.SecretKey.generate()
      {:ok, set} = CPub.DMC.Set.new(secret_key.public_key)

      assert {:ok, set_definition} = CPub.DMC.Definition.get(set.id)
      assert set_definition.id === set.id

      assert set_definition.root_public_key === secret_key.public_key
    end
  end

  describe "state/1" do
    test "adds without signatures are ignored" do
      secret_key = CPub.Signify.SecretKey.generate()
      {:ok, set} = CPub.DMC.Set.new(secret_key.public_key)

      element = ERIS.encode_urn("Hello world!")
      assert {:ok, add_op} = CPub.DMC.Set.Add.new(set.id, element)

      assert {:ok, state} = CPub.DMC.Set.state(set)
      assert MapSet.size(state) === 0
    end

    test "add single element" do
      secret_key = CPub.Signify.SecretKey.generate()
      {:ok, set} = CPub.DMC.Set.new(secret_key.public_key)

      element = ERIS.encode_read_capability("Hello world!")
      assert {:ok, add_op} = CPub.DMC.Set.Add.new(set.id, element)
      assert {:ok, signature} = CPub.Signify.sign(add_op.id, secret_key)
      assert {:ok, _} = CPub.Signify.Signature.insert(signature)

      assert {:ok, state} = CPub.DMC.Set.state(set)
      assert MapSet.member?(state, element)
      assert MapSet.size(state) === 1
    end

    test "add and remove single element" do
      secret_key = CPub.Signify.SecretKey.generate()
      {:ok, set} = CPub.DMC.Set.new(secret_key.public_key)

      element = ERIS.encode_read_capability("Hello world!")
      assert {:ok, add_op} = CPub.DMC.Set.Add.new(set.id, element)
      assert {:ok, signature} = CPub.Signify.sign(add_op.id, secret_key)
      assert {:ok, _} = CPub.Signify.Signature.insert(signature)

      assert {:ok, remove_op} = CPub.DMC.Set.Remove.new(set.id, add_op.id)
      assert {:ok, remove_signature} = CPub.Signify.sign(remove_op.id, secret_key)
      assert {:ok, _} = CPub.Signify.Signature.insert(remove_signature)

      assert {:ok, state} = CPub.DMC.Set.state(set.id)
      assert MapSet.size(state) === 0
    end
  end
end
