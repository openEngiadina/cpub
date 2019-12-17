defmodule CPub.ActivityPubTest do

  use ExUnit.Case
  use CPub.DataCase

  doctest CPub.ActivityPub

  alias CPub.ActivityPub

  alias CPub.ActivityPub.Activity
  alias CPub.Objects.Object

  test "create activity" do
    activity_id = CPub.ID.generate()
    activity = RDF.Turtle.read_file!("./test/data/test_activity.ttl", base_iri: activity_id)

    assert {:ok, %{activity: %Activity{}, object: %Object{}}} =
      ActivityPub.create(activity[activity_id], activity)

  end

end
