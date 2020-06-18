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

      {:ok, request} = CPub.ActivityPub.handle_activity(data, user)

      # Ensure activity was inserted
      assert request.activity

      # Ensure associated object was inserted
      assert CPub.Repo.exists?(
               from o in CPub.Object, where: o.id in ^request.activity[AS.object()]
             )

      # T O D O: check that activity was placed in user outbox
      # T O D O: add recipients and check for proper delivery
    end
  end
end
