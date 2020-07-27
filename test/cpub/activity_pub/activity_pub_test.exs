defmodule CPub.ActivityPubTest do
  use ExUnit.Case
  use ExUnitProperties
  use CPub.DataCase

  alias RDF.{Description, Graph}

  alias CPub.NS.ActivityStreams, as: AS

  doctest CPub.ActivityPub

  property "create object" do
    # Create a user
    {:ok, user} = CPub.User.create(%{username: "alice", password: "123"})

    check all(object <- RDF.StreamData.description()) do
      activity_id = CPub.ID.generate(type: :activity)

      data =
        Graph.new()
        |> Graph.add(
          Description.new(activity_id)
          |> Description.add(RDF.type(), AS.Create)
          |> Description.add(AS.object(), object.subject)
        )
        |> Graph.add(object)
        |> RDF.Skolem.skolemize_graph()

      assert {:ok, request} = CPub.ActivityPub.handle_activity(data, user)

      activity =
        request.activity
        |> CPub.Repo.preload([:activity_object, :object])

      assert CPub.Repo.get(CPub.ActivityPub.Activity, request.activity.id)
      assert CPub.Repo.get(CPub.Object, activity.activity_object_id)
      assert CPub.Repo.get(CPub.Object, activity.object_id)

      # TODO: check that activity was placed in user outbox
      # TODO: add recipients and check for proper delivery
    end
  end
end
