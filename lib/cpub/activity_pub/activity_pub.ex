defmodule CPub.ActivityPub do
  @moduledoc """
  ActivityPub context
  """

  alias CPub.{Activity, Object, User}
  alias CPub.ActivityPub.Request
  alias CPub.NS.ActivityStreams, as: AS

  @activity_streams RDF.Turtle.read_file!("./priv/vocabs/activitystreams2.ttl")
  @doc """
  The ActivityStreams 2.0 ontology
  """
  @spec activity_streams :: RDF.Graph.t()
  def activity_streams, do: @activity_streams

  @activity_types SPARQL.execute_query(
                    @activity_streams,
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
  @spec activity_types :: [RDF.IRI.t()]
  def activity_types, do: @activity_types

  # @doc """
  # Gets an actor.
  # """
  # def get_actor!(id), do: Repo.get!(Actor, id)

  @doc """
  Creates an ActivityPub activity, computes side-effects and runs everything in a transaction.
  """
  @spec handle_activity(RDF.IRI.t(), RDF.Graph.t(), User.t()) :: Request.commit_result()
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

  @spec ensure_correct_actor(Request.t()) :: Request.t()
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

  @spec insert_activity(Request.t()) :: Request.t()
  defp insert_activity(%Request{} = request) do
    activity =
      request.activity
      |> Activity.new()
      |> Activity.create_changeset()

    Request.insert(request, :activity, activity)
  end

  @spec set_object_id(Request.t()) :: Request.t()
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
  @spec create_object(Request.t()) :: Request.t()
  defp create_object(request) do
    if RDF.iri(AS.Create) in request.activity[RDF.type()] do
      case request.data[request.id][AS.object()] do
        [original_object_id] ->
          object =
            Object.new(%{
              id: request.object_id,
              data: %{request.data[original_object_id] | subject: request.object_id},
              activity_id: request.id
            })

          # replace subject
          Request.insert(request, request.object_id, Object.create_changeset(object))

        _ ->
          Request.error(request, :create_object, "could not find object")
      end
    else
      request
    end
  end
end
