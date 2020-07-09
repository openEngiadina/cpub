defmodule CPub.ActivityPubTest do
  use ExUnit.Case
  use ExUnitProperties
  use CPub.DataCase

  import Ecto.Query, only: [from: 2]

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

      # Ensure activity was inserted
      assert request.activity

      assert CPub.Repo.get(CPub.Activity, request.activity.id)
      assert CPub.Repo.get(CPub.Object, request.activity.activity_object_id)
      assert CPub.Repo.get(CPub.Object, request.activity.object_id)

      # Ensure associated object was inserted
      assert CPub.Repo.exists?(
               from o in CPub.Object,
                 where: o.id in ^request.activity.activity_object[:base_subject][AS.object()]
             )

      # TODO: check that activity was placed in user outbox
      # TODO: add recipients and check for proper delivery
    end
  end
end
