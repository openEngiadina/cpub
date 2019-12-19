defmodule CPub.ActivityPubTest do

  use ExUnit.Case
  use CPub.DataCase

  doctest CPub.ActivityPub

  import RDF.Sigils
  alias RDF.Graph
  alias RDF.Description

  alias CPub.ActivityPub
  alias CPub.ActivityPub.Activity
  alias CPub.ActivityPub.Actor
  alias CPub.Objects.Object
  alias CPub.LDP
  alias CPub.LDP.BasicContainer

  alias CPub.NS.ActivityStreams, as: AS

  test "create activity" do

    # Create an actor
    {:ok, %{actor: actor}} = ActivityPub.create_actor()

    activity_id = CPub.ID.generate()

    data = Graph.new()
    |> Graph.add(
      Description.new(activity_id)
      |> Description.add(RDF.type, AS.Create)
      |> Description.add(AS.actor, actor.id)
      |> Description.add(AS.object, ~B<object>)
    )
    |> Graph.add(
      Description.new(~B<object>)
      |> Description.add(RDF.type, AS.Note)
      |> Description.add(AS.content, ~L<Just a simple note>))

    # create activity
    assert {:ok, %{activity: %Activity{}, object: %Object{}}} =
      ActivityPub.create_activity(activity_id, data)

    # check that activity has been placed in actor outbox
    assert LDP.get_basic_container!(actor[AS.outbox] |> List.first()) |> Enum.member?(activity_id)

  end

  test "create activity and deliver to container" do

    # Create an actor
    {:ok, %{actor: actor}} = ActivityPub.create_actor()

    # create a container
    assert {:ok, %BasicContainer{} = container} = LDP.create_basic_container()

    activity_id = CPub.ID.generate()

    data = Graph.new()
    |> Graph.add(
      Description.new(activity_id)
      |> Description.add(RDF.type, AS.Create)
      |> Description.add(AS.actor, actor.id)
      |> Description.add(AS.object, ~B<object>)
      |> Description.add(AS.to, container.id)
    )
    |> Graph.add(
      Description.new(~B<object>)
      |> Description.add(RDF.type, AS.Note)
      |> Description.add(AS.content, ~L<Just a simple note>))


    # create activity
    assert {:ok, %{activity: %Activity{},
                   object: %Object{}}} =
      ActivityPub.create_activity(activity_id, data)

    # check that activity has been added to container
    assert LDP.get_basic_container!(container.id) |> Enum.member?(activity_id)

    # check that activity has been placed in actor outbox
    assert LDP.get_basic_container!(actor[AS.outbox] |> List.first()) |> Enum.member?(activity_id)
  end

  test "add activity" do

    # Create an actor
    {:ok, %{actor: actor}} = ActivityPub.create_actor()

    # create a container
    assert {:ok, %BasicContainer{} = container} = LDP.create_basic_container()

    activity_id = CPub.ID.generate()

    object = ~I<http://example.com>

    data = Graph.new()
    |> Graph.add(
      Description.new(activity_id)
      |> Description.add(RDF.type, AS.Add)
      |> Description.add(AS.actor, actor.id)
      |> Description.add(AS.object, object)
      |> Description.add(AS.target, container.id))

    # create activity
    assert {:ok, %{activity: %Activity{}}} =
      ActivityPub.create_activity(activity_id, data)

    # check that activity has been added to container
    assert LDP.get_basic_container!(container.id) |> Enum.member?(object)

    # check that activity has been placed in actor outbox
    assert LDP.get_basic_container!(actor[AS.outbox] |> List.first()) |> Enum.member?(activity_id)
  end

  test "create actor" do
    assert {:ok, %{actor: %Actor{},
                   outbox: %BasicContainer{},
                   inbox: %BasicContainer{}}} =
      ActivityPub.create_actor()
  end

  test "create actor with wrong type fails" do
    assert true
  end

end
