defmodule CPub.ActivityPubTest do

  use ExUnit.Case
  use CPub.DataCase

  doctest CPub.ActivityPub

  import RDF.Sigils
  alias RDF.Graph
  alias RDF.Description

  alias CPub.ActivityPub
  alias CPub.ActivityPub.Activity
  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.Objects.Object
  alias CPub.LDP.BasicContainer

  test "create activity" do

    activity_id = CPub.ID.generate()

    data = Graph.new()
    |> Graph.add(
      Description.new(activity_id)
      |> Description.add(RDF.type, AS.Create)
      |> Description.add(AS.object, ~B<object>))
    |> Graph.add(
      Description.new(~B<object>)
      |> Description.add(RDF.type, AS.Note)
      |> Description.add(AS.content, ~L<Just a simple note>))

    assert {:ok, %{activity: %Activity{}, object: %Object{}}} =
      ActivityPub.create(activity_id, data)

  end

  test "create activity and deliver to container" do

    # create a container
    assert {:ok, %BasicContainer{} = container} = BasicContainer.create()

    activity_id = CPub.ID.generate()

    data = Graph.new()
    |> Graph.add(
      Description.new(activity_id)
      |> Description.add(RDF.type, AS.Create)
      |> Description.add(AS.object, ~B<object>)
      |> Description.add(AS.to, container.id)
    )
    |> Graph.add(
      Description.new(~B<object>)
      |> Description.add(RDF.type, AS.Note)
      |> Description.add(AS.content, ~L<Just a simple note>))


    # create activity
    assert {:ok, %{activity: %Activity{},
                   object: %Object{},
                   deliver_local: %BasicContainer{}}} =
      ActivityPub.create(activity_id, data)

    # check that activity has been added to container
    assert BasicContainer.get!(container.id) |> Enum.member?(activity_id)

  end

  test "add activity" do

    # create a container
    assert {:ok, %BasicContainer{} = container} = BasicContainer.create()

    activity_id = CPub.ID.generate()

    object = ~I<http://example.com>

    data = Graph.new()
    |> Graph.add(
      Description.new(activity_id)
      |> Description.add(RDF.type, AS.Add)
      |> Description.add(AS.object, object)
      |> Description.add(AS.target, container.id))

    # create activity
    assert {:ok, %{activity: %Activity{},
                   deliver_local: %BasicContainer{}}} =
      ActivityPub.create(activity_id, data)

    # check that activity has been added to container
    assert BasicContainer.get!(container.id) |> Enum.member?(object)

  end

end
