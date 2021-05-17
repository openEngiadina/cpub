# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.User.OutboxTest do
  use ExUnit.Case
  use CPub.RDFCase
  use CPub.DataCase

  import RDF.Sigils

  alias CPub.NS.ActivityStreams, as: AS

  alias CPub.User
  alias CPub.User.Outbox

  alias CPub.Web.Path

  doctest CPub.User.Outbox

  @rdf_type ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>
  @as_public ~I<https://www.w3.org/ns/activitystreams#Public>
  @as_actor ~I<https://www.w3.org/ns/activitystreams#actor>
  @as_attributed_to ~I<https://www.w3.org/ns/activitystreams#attributedTo>
  @as_to ~I<https://www.w3.org/ns/activitystreams#to>
  @as_cc ~I<https://www.w3.org/ns/activitystreams#cc>

  setup do
    {:ok, alice} = User.create("alice")
    {:ok, bob} = User.create("bob")

    object =
      EX.Object
      |> RDF.type(AS.Note)
      |> AS.content("Hello")
      |> AS.to("https://example.org/~john/" |> RDF.iri())
      |> AS.bto("https://example.org/~jane/" |> RDF.iri())
      |> AS.cc(@as_public)
      |> RDF.graph()

    non_as_object =
      EX.NonASObject
      |> RDF.type("http://schema.org/Event" |> RDF.iri())
      |> RDF.graph()

    {:ok, %{alice: alice, bob: bob, object: object, non_as_object: non_as_object}}
  end

  describe "post/2 for Create activity" do
    setup %{object: object, non_as_object: non_as_object} do
      bob_iri = "local:bob" |> RDF.iri()

      activity =
        EX.Example
        |> RDF.type(AS.Create)
        |> AS.object(EX.Object)
        |> AS.to(bob_iri)
        |> RDF.Data.merge(object)

      activity_with_non_as_object =
        EX.Example
        |> RDF.type(AS.Create)
        |> AS.object(EX.NonASObject)
        |> AS.to(bob_iri)
        |> RDF.Data.merge(non_as_object)

      {:ok, activity: activity, activity_with_non_as_object: activity_with_non_as_object}
    end

    test "object without wrapping activity", %{alice: alice, object: object} do
      assert {:ok, {activity_read_cap, recipients}} = Outbox.post(alice, object)

      with {:ok, activity_fg} <- CPub.ERIS.get_rdf(activity_read_cap),
           as_create <- [AS.Create |> RDF.iri()] |> MapSet.new(),
           alice_iri <- [alice |> Path.user() |> RDF.iri()] |> MapSet.new(),
           to <-
             [alice |> Path.user_followers() |> RDF.iri() | object[EX.Object][AS.to()]]
             |> MapSet.new(),
           bto <- object[EX.Object][AS.bto()] |> MapSet.new(),
           cc <- [@as_public] |> MapSet.new(),
           all_recipients <- to |> MapSet.union(bto) |> MapSet.union(cc),
           {:ok, magnet} <-
             activity_fg.statements[AS.object()]
             |> MapSet.to_list()
             |> List.first()
             |> to_string()
             |> Magnet.decode(),
           {:ok, object_fg} <-
             magnet
             |> Map.get(:info_hash)
             |> List.first()
             |> CPub.ERIS.get_rdf(),
           as_note <- [AS.Note |> RDF.iri()] |> MapSet.new() do
        assert %{
                 @rdf_type => ^as_create,
                 @as_actor => ^alice_iri,
                 @as_to => ^to,
                 @as_cc => ^cc
               } = activity_fg.statements

        assert %{
                 @rdf_type => ^as_note,
                 @as_attributed_to => ^alice_iri,
                 @as_to => ^to,
                 @as_cc => ^cc
               } = object_fg.statements

        assert recipients |> Map.keys() |> MapSet.new() |> MapSet.equal?(all_recipients)
      end
    end

    test "non-activitystreams object without wrapping activity",
         %{alice: alice, non_as_object: non_as_object} do
      assert {:ok, {_, _}} = Outbox.post(alice, non_as_object)
    end

    test "activity with embedded object", %{alice: alice, activity: activity, object: object} do
      assert {:ok, {activity_read_cap, recipients}} = Outbox.post(alice, activity)

      with {:ok, activity_fg} <- CPub.ERIS.get_rdf(activity_read_cap),
           {:ok, magnet} <-
             activity_fg.statements[AS.object()]
             |> MapSet.to_list()
             |> List.first()
             |> to_string()
             |> Magnet.decode(),
           {:ok, object_fg} <-
             magnet
             |> Map.get(:info_hash)
             |> List.first()
             |> CPub.ERIS.get_rdf(),
           as_create <- [AS.Create |> RDF.iri()] |> MapSet.new(),
           as_note <- [AS.Note |> RDF.iri()] |> MapSet.new(),
           alice_iri <- [alice |> Path.user() |> RDF.iri()] |> MapSet.new(),
           object_to <-
             [alice |> Path.user_followers() |> RDF.iri() | object[EX.Object][AS.to()]]
             |> MapSet.new(),
           object_bto <- object[EX.Object][AS.bto()] |> MapSet.new(),
           object_cc <- object[EX.Object][AS.cc()] |> MapSet.new(),
           activity_to <-
             activity[EX.Example][AS.to()] |> MapSet.new(),
           to <- object_to |> MapSet.union(activity_to),
           all_recipients <- to |> MapSet.union(object_bto) |> MapSet.union(object_cc) do
        assert %{
                 @rdf_type => ^as_create,
                 @as_actor => ^alice_iri,
                 @as_to => ^to,
                 @as_cc => ^object_cc
               } = activity_fg.statements

        assert %{
                 @rdf_type => ^as_note,
                 @as_attributed_to => ^alice_iri,
                 @as_to => ^to,
                 @as_cc => ^object_cc
               } = object_fg.statements

        assert recipients |> Map.keys() |> MapSet.new() |> MapSet.equal?(all_recipients)
      end
    end

    test "activity with embedded non-activitystreams object",
         %{alice: alice, activity_with_non_as_object: activity_with_non_as_object} do
      assert {:ok, {_, _}} = Outbox.post(alice, activity_with_non_as_object)
    end

    test "activity with object uri", %{alice: alice} do
      activity =
        EX.Example
        |> RDF.type(AS.Create)
        |> AS.object("https://example.org/object/" |> RDF.iri())
        |> AS.to("local:bob" |> RDF.iri())
        |> RDF.graph()

      assert {:error, :no_object} = Outbox.post(alice, activity)
    end
  end
end
