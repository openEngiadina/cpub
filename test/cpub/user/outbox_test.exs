# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.User.OutboxTest do
  use ExUnit.Case
  use CPub.RDFCase
  use CPub.DataCase

  alias CPub.NS.ActivityStreams, as: AS

  alias CPub.User

  doctest CPub.User.Outbox

  setup do
    with {:ok, alice} <- User.create("alice"),
         {:ok, bob} <- User.create("bob") do
      {:ok, %{alice: alice, bob: bob}}
    end
  end

  describe "post/2" do
    test "local delivery", %{alice: alice, bob: bob} do
      object =
        EX.Object
        |> RDF.type(AS.Note)
        |> AS.content("Hello")
        |> RDF.graph()

      bob_iri = RDF.iri("local:bob")

      activity =
        EX.Example
        |> RDF.type(AS.Create)
        |> AS.object(EX.Object)
        |> AS.to(bob_iri)
        |> RDF.Data.merge(object)

      assert {:ok, {activity_read_cap, recipients}} = User.Outbox.post(alice, activity)
      assert %{^bob_iri => {:ok, :local}} = recipients

      assert {:ok, bob_inbox} = User.Inbox.get(bob)
      assert activity_read_cap in bob_inbox
    end
  end
end
