defmodule CPub.ActivityPub do
  @moduledoc """
  ActivityPub context
  """

  alias CPub.NS.ActivityStreams, as: AS

  alias CPub.Repo
  alias CPub.ID

  alias CPub.Users.User

  alias CPub.LDP.RDFSource

  alias CPub.ActivityPub.Activity
  alias CPub.ActivityPub.Actor

  alias CPub.ActivityPub.Request

  alias RDF.Description
  alias RDF.Graph

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
  def create_activity(%RDF.IRI{} = activity_id, %RDF.Graph{} = data, %User{} = user) do
    # create a new pipeline
    Request.new(activity_id, data, user)

    # Ensure the actor is set correctly
    |> ensure_correct_actor

    # Extract and load recipients
    |> get_recipients

    # Set the object id to a newly created id
    |> set_object_id

    # insert activity object
    |> insert_activity

    # insert the object (if a Create activity)
    |> create_object

    |> handle_add

    |> deliver_local

    |> place_in_outbox

    # commit the request
    |> Request.commit

  end

  defp ensure_correct_actor(%Request{} = request) do
    case request.activity[AS.actor] do

      nil ->
        # set actor
        %{request | activity: request.activity
          |> RDF.Description.add(AS.actor, request.user.id)
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
    |> Request.insert(:activity, Activity.new(request.activity) |> Activity.changeset())

    # Grant user access to the created activity
    |> Request.authorize(request.user, request.id, read: true, write: true)

    # Grant recipients read access to the created activity
    |> Request.authorize(request.recipients, request.id, read: true)

  end

  defp get_recipients(%Request{} = request) do
    %{request | recipients: [AS.to, AS.cc, AS.bcc, AS.bto]
      |> Enum.map(&(Access.get(request.data[request.id], &1)))
      |> Enum.reject(&is_nil/1)
      |> Enum.concat()
      |> Enum.filter(&ID.is_local?/1)}
  end

  defp set_object_id(%Request{} = request) do
    if RDF.iri(AS.Create) in request.activity[RDF.type] do
      %{request |
        activity: request.activity
        |> Description.delete_predicates(AS.object)
        |> Description.add(AS.object, request.object_id)
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
          RDFSource.new(id: request.object_id,
            data: request.data
            # remove the activity description and the original object description
            |> Graph.delete_subjects([original_object_id, request.id])
            # replace subject of object with new id and add to graph
            |> Graph.add(%{request.data[original_object_id] | subject: request.object_id}))
            |> RDFSource.changeset()
          )
          |> Request.authorize(request.user, request.object_id, read: true, write: true)
          |> Request.authorize(request.recipients, request.object_id, read: true)

        _ ->
          request
          |> Request.error(:create_object, "could not find object")

      end
    else
      request
    end
  end

  # TODO: move add to container logic from CPub.LDP here
  defp add_to_local_container(request, to, element) do
    case CPub.LDP.add_to_container(to, element) do
      {:error, _} ->
        request
        |> Request.error(to, "do not know how to add to local container")

      changeset ->
        request
        |> Request.update(to, changeset)
    end
  end

  defp deliver_local(request) do
    request.recipients
    |> List.foldl(request, &(add_to_local_container(&2, &1, request.id)))
  end

  defp place_in_outbox(request) do
    with [outbox] <- request.user.actor[AS.outbox] do
      request
      |> add_to_local_container(outbox, request.id)
    else
      _ -> request |> Request.error(:place_in_outbox, "can not determine actor outbox")
    end
  end

  defp handle_add(request) do
    if RDF.iri(AS.Add) in request.activity[RDF.type] do
      with [object_id] <- request.activity[AS.object],
           [target] <- request.activity[AS.target] do
        request
        |> add_to_local_container(target, object_id)
      else
        _ ->
          request |> Request.error(:handle_add, "can not get object or target")
      end
    else
      request
    end
  end

end
