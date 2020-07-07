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
  alias RDF.FragmentGraph

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
  def handle_activity(%RDF.Graph{} = graph, %User{} = user) do
    # create a new pipeline
    Request.new(graph, user)

    # extract activity from the data as Fragment Graph
    |> extract_activity

    # extract object from the data as Fragment Graph
    |> extract_object

    # ensure the actor is set correctly
    |> ensure_correct_actor

    # bcc and bto are not supported
    |> ensure_no_bcc

    # insert activity
    |> insert_activity

    # commit the request
    |> Request.commit()
  end

  @spec extract_activity(Request.t()) :: Request.t()
  defp extract_activity(%Request{} = request) do
    case find_activities(request.graph) do
      [activity_id] ->
        activity =
          RDF.FragmentGraph.new(activity_id)
          |> FragmentGraph.add(request.graph)
          |> FragmentGraph.set_base_subject(RDF.UUID.generate())

        %{request | activity_object: activity}

      _ ->
        Request.error(
          request,
          :extract_activity,
          "can not find ActivityStreams activity in RDF graph"
        )
    end
  end

  # TODO: this should be an utility function in RDF.FragmentGraph. Maybe even a
  # general way of mapping over `RDF.Data` structures efficiently.
  defp replace_object_in_fragment_graph(fg, from, to) do
    FragmentGraph.new(fg.base_subject)
    |> FragmentGraph.add(
      RDF.Data.statements(fg)
      |> Enum.map(fn {s, p, o} ->
        case o do
          ^from -> {s, p, to}
          _ -> {s, p, o}
        end
      end)
    )
  end

  @spec extract_object(Request.t()) :: Request.t()
  defp extract_object(%Request{activity_object: activity_object} = request) do
    case activity_object[:base_subject][AS.object()] do
      [object_id] ->
        with generated_object_id <- RDF.UUID.generate() do
          %{
            request
            | object:
                FragmentGraph.new(object_id)
                |> FragmentGraph.add(request.graph)
                |> FragmentGraph.set_base_subject(generated_object_id),
              activity_object:
                activity_object
                |> replace_object_in_fragment_graph(object_id, generated_object_id)
          }
        end

      [] ->
        request

      _ ->
        Request.error(request, :extract_object, "multiple objects in graph")
    end
  end

  @spec ensure_correct_actor(Request.t()) :: Request.t()
  defp ensure_correct_actor(%Request{} = request) do
    case request.activity_object[:base_subject][AS.actor()] do
      nil ->
        # set actor
        %{
          request
          | activity_object:
              request.activity_object
              |> FragmentGraph.add(AS.actor(), User.actor_url(request.user))
        }

      [actor_in_activity] ->
        if actor_in_activity != User.actor_url(request.user) do
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

  defp ensure_no_bcc(%Request{} = request) do
    cond do
      request.activity_object[:base_subject][AS.bcc()] ->
        Request.error(request, :ensure_no_bcc, "bcc is not supported")

      request.activity_object[:base_subject][AS.bto()] ->
        Request.error(request, :ensure_no_bcc, "bto is not supported")

      true ->
        request
    end
  end

  @spec insert_activity(Request.t()) :: Request.t()
  defp insert_activity(%Request{} = request) do
    object =
      if RDF.iri(AS.Create) in request.activity_object[:base_subject][RDF.type()] do
        request.object |> Object.new()
      else
        nil
      end

    activity =
      Activity.new(
        request.activity_object |> Object.new(),
        object
      )

    %{request | activity: activity}
    |> Request.insert(:activity, activity |> Activity.create_changeset())
  end
end
