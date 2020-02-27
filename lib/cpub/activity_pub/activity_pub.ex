defmodule CPub.ActivityPub do
  @moduledoc """
  ActivityPub context
  """

  alias CPub.{Activity, Object, Repo, User}
  alias CPub.ActivityPub.Request
  alias CPub.NS.ActivityStreams, as: AS

  @activitystreams RDF.Turtle.read_file!("./priv/vocabs/activitystreams2.ttl")
  @doc """
  The ActivityStreams 2.0 ontology
  """
  def activitystreams, do: @activitystreams

  @doc """
  Gets an actor.
  """
  def get_actor!(id), do: Repo.get!(Actor, id)

  @activity_types SPARQL.execute_query(
                    @activitystreams,
                    SPARQL.query("""
                    select ?activity_type
                    where {
                      ?activity_type rdfs:subClassOf as:Activity .
                    }
                    """)
                  ).results
                  |> Enum.map(& &1["activity_type"])
  @doc """
  List of all ActivityStreams Activity types
  """
  def activity_types, do: @activity_types

  @doc """
  Creates an ActivityPub activity, computes side-effects and runs everything in a transaction.
  """
  def handle_activity(%RDF.IRI{} = activity_id, %RDF.Graph{} = data, %User{} = user) do
    # create a new pipeline
    Request.new(activity_id, data, user)

    # Ensure the actor is set correctly
    |> ensure_correct_actor

    # Set the object id to a newly created id
    |> set_object_id

    # insert activity object
    |> insert_activity

    # insert the object (if a Create activity)
    |> create_object

    # |> handle_add

    # |> deliver_local

    # |> place_in_outbox

    # commit the request
    |> Request.commit()
  end

  defp ensure_correct_actor(%Request{} = request) do
    case request.activity[AS.actor()] do
      nil ->
        # set actor
        %{request | activity: RDF.Description.add(request.activity, AS.actor(), request.user.id)}

      [actor_in_activity] ->
        if actor_in_activity != request.user.id do
          Request.error(
            request,
            :ensure_correct_actor,
            "actor set in activity does not match user"
          )
        end

      _ ->
        Request.error(request, :ensure_correct_actor, "multiple actors in activity")
    end
  end

  defp insert_activity(%Request{} = request) do
    activity =
      request.activity
      |> Activity.new()
      |> Activity.changeset()

    Request.insert(request, :activity, activity)
  end

  defp set_object_id(%Request{} = request) do
    if RDF.iri(AS.Create) in request.activity[RDF.type()] do
      activity =
        request.activity
        |> RDF.Description.delete_predicates(AS.object())
        |> RDF.Description.add(AS.object(), request.object_id)

      %{request | activity: activity}
    else
      # don't do anything if not a Create activity
      request
    end
  end

  # Creates an object if it is a Create activity
  defp create_object(request) do
    if RDF.iri(AS.Create) in request.activity[RDF.type()] do
      case request.data[request.id][AS.object()] do
        [original_object_id] ->
          object =
            Object.new(
              id: request.object_id,
              data: %{request.data[original_object_id] | subject: request.object_id},
              activity_id: request.id
            )

          # replace subject
          Request.insert(request, request.object_id, Object.changeset(object))

        _ ->
          Request.error(request, :create_object, "could not find object")
      end
    else
      request
    end
  end
end
