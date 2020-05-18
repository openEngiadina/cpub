defmodule CPub.ActivityPub do
  @moduledoc """
  ActivityPub context
  """

  # NOTE/TODO: This requires some major cleanup.
  # After a couple of weeks of not hacking on this following becomes clear:
  # - manually generating ids and shuffling them about is a hassle
  # - a nice query language would be immensly helpful
  #
  # possible solutions:
  # - content-addressable storage for no worries about ids
  # - datalog as a query language

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

  @doc """
  Finds IDs of Activitystreams Activities in some `RDF.Data`
  """
  def find_activities(data) do
    SPARQL.execute_query(RDF.Data.merge(data, @activity_streams), """
    select ?activity_id
    where {
      ?activity_type rdfs:subClassOf as:Activity .
      ?activity_id rdf:type ?activity_type .
    }
    """)
    |> Enum.map(& &1["activity_id"])
  end

  @doc """
  Creates an ActivityPub activity, computes side-effects and runs everything in a transaction.
  """
  @spec handle_activity(RDF.Graph.t(), User.t()) :: Request.commit_result()
  def handle_activity(%RDF.Graph{} = data, %User{} = user) do
    # create a new pipeline
    Request.new(data, user)

    # Set activity from the data
    |> set_activity

    # Ensure the actor is set correctly
    |> ensure_correct_actor

    # Get object and set id in activity
    |> get_object

    # insert activity object
    |> insert_activity

    # insert the object (if a Create activity)
    |> insert_object

    # |> handle_add

    # |> deliver_local

    # |> place_in_outbox

    # commit the request
    |> Request.commit()
  end

  @spec set_activity(Request.t()) :: Request.t()
  defp set_activity(%Request{} = request) do
    case find_activities(request.data) do
      [activity_id | _] ->
        activity_description = request.data[activity_id]
        new_activity_id = CPub.ID.generate(type: :activity)

        %{
          request
          | id: new_activity_id,
            activity: %{activity_description | subject: new_activity_id}
        }

      [] ->
        Request.error(
          request,
          :set_activity,
          "can not find ActivityStreams activity in data"
        )
    end
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

  @spec get_object(Request.t()) :: Request.t()
  defp get_object(%Request{} = request) do
    if RDF.iri(AS.Create) in request.activity[RDF.type()] do
      # the id of the object in the data received
      original_object_id = request.activity[AS.object()] |> List.first()

      # generate a new id
      object_id = CPub.ID.generate(type: :object)

      # extract object description
      object_description = %{request.data[original_object_id] | subject: object_id}

      # replace the reference to object in activity
      activity =
        request.activity
        |> RDF.Description.delete_predicates(AS.object())
        |> RDF.Description.add(AS.object(), object_id)

      %{request | activity: activity, object: object_description}
    else
      # don't do anything if not a Create activity
      request
    end
  end

  # Creates an object if it is a Create activity
  @spec insert_object(Request.t()) :: Request.t()
  defp insert_object(request) do
    if RDF.iri(AS.Create) in request.activity[RDF.type()] do
      object =
        Object.new(%{
          id: request.object.subject,
          data: request.object,
          activity_id: request.id
        })

      request
      |> Request.insert(request.object.subject, Object.create_changeset(object))
    else
      request
    end
  end
end
