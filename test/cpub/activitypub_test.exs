defmodule CPub.ActivityPubTest do

  use ExUnit.Case
  use CPub.DataCase

  doctest CPub.ActivityPub

  import RDF.Sigils
  alias RDF.Graph
  alias RDF.Description

  alias CPub.ActivityPub
  alias CPub.NS.ActivityStreams, as: AS

  alias CPub.ActivityPub.Activity
  alias CPub.Objects.Object

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

end
