defmodule CPub.ActivityPub do
  @moduledoc """
  ActivityPub context
  """

  alias CPub.NS.ActivityStreams, as: AS

  alias CPub.Repo
  alias CPub.User
  alias CPub.Activity
  alias CPub.Object
  alias CPub.ActivityPub.Request

  @activitystreams RDF.Turtle.read_file!("./priv/vocabs/activitystreams2.ttl")
  @doc """
  The ActivityStreams 2.0 ontology
  """
  def activitystreams, do: @activitystreams

  @doc """
  Gets an actor.
  """
  def get_actor!(id), do: Repo.get!(Actor, id)

  @activity_types (SPARQL.execute_query(@activitystreams,
    SPARQL.query("""
    select ?activity_type
    where {
      ?activity_type rdfs:subClassOf as:Activity .
    }
    """
    ))).results |> Enum.map(&(&1["activity_type"]))
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
    |> Request.commit

  end

  defp ensure_correct_actor(%Request{} = request) do
    case request.activity[AS.actor] do

      nil ->
        # set actor
        %{request | activity: request.activity
          |> Activity.add(AS.actor, request.user.id)
         }

      [actor_in_activity] ->
        if actor_in_activity != request.user.id do
          request
          |> Request.error(:ensure_correct_actor, "actor set in activity does not match user")
        end

      _ ->
        request
        |> Request.error(:ensure_correct_actor, "multiple actors in activity")

    end
  end

  defp insert_activity(%Request{} = request) do
    request
    |> Request.insert(:activity, request.activity |> Activity.changeset())
  end

  defp set_object_id(%Request{} = request) do
    if RDF.iri(AS.Create) in request.activity[RDF.type] do
      %{request |
        activity: request.activity
        |> Activity.delete_predicates(AS.object)
        |> Activity.add(AS.object, request.object_id)
      }
    else
      # don't do anything if not a Create activity
      request
    end
  end

  # Creates an object if it is a Create activity
  defp create_object(request) do
    if RDF.iri(AS.Create) in request.activity[RDF.type] do
      case request.data[request.id][AS.object] do

        [original_object_id] ->
          # replace subject
          request
          |> Request.insert(request.object_id,
          Object.new(
            id: request.object_id,
            data: %{request.data[original_object_id] | subject: request.object_id},
            activity_id: request.id)
          |> Object.changeset())

        _ ->
          request
          |> Request.error(:create_object, "could not find object")

      end
    else
      request
    end
  end

end
