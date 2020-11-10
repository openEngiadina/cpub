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

  alias CPub.{Object, User}
  alias CPub.ActivityPub.{Activity, Request}

  alias CPub.NS.ActivityStreams, as: AS
  alias RDF.NS.RDFS

  alias RDF.FragmentGraph

  @activity_streams RDF.Turtle.read_file!("./priv/vocabs/activitystreams2.ttl")

  @doc """
  Creates an ActivityPub activity, computes side-effects and runs everything in a transaction.
  """
  @spec handle_activity(RDF.Graph.t(), User.t()) :: Request.commit_result()
  def handle_activity(%RDF.Graph{} = graph, %User{} = user) do
    # create a new pipeline
    Request.new(graph, user)

    # extract activity from the data as Fragment Graph
    |> extract_activity

    # ensure the actor is set correctly
    |> ensure_correct_actor

    # extract object from the data as Fragment Graph
    |> extract_object

    # bcc and bto are not supported
    |> ensure_no_bcc

    # extract the recipients
    |> extract_recipients()

    # insert the object
    |> insert_object()

    # insert the activity object
    |> insert_activity_object()

    # insert activity
    |> insert_activity()

    # commit the request
    |> Request.commit()
  end

  @spec extract_activity(Request.t()) :: Request.t()
  defp extract_activity(%Request{} = request) do
    case [
           {:activity_type?, RDFS.subClassOf(), AS.Activity},
           {:activity_id?, RDF.type(), :activity_type?}
         ]
         |> RDF.Query.execute(RDF.Data.merge(request.graph, @activity_streams)) do
      {:ok, [%{activity_id: activity_id}]} ->
        activity =
          RDF.FragmentGraph.new(activity_id)
          |> FragmentGraph.add(request.graph)

        request
        |> Request.assign(:activity, activity)

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
  defp extract_object(%Request{} = request) do
    if RDF.iri(AS.Create) in request.assigns.activity[:base_subject][RDF.type()] do
      case request.assigns.activity[:base_subject][AS.object()] do
        [object_id] ->
          with object <-
                 FragmentGraph.new(object_id)
                 |> FragmentGraph.add(request.graph)
                 |> FragmentGraph.set_base_subject_to_hash(fn data ->
                   data |> ERIS.encode_urn() |> RDF.IRI.new()
                 end),
               new_activity <-
                 request.assigns.activity
                 |> replace_object_in_fragment_graph(object_id, object.base_subject)
                 |> FragmentGraph.set_base_subject_to_hash(fn data ->
                   data |> ERIS.encode_urn() |> RDF.IRI.new()
                 end) do
            request
            |> Request.assign(:activity, new_activity)
            |> Request.assign(:object, object)
          end

        [] ->
          request

        _ ->
          Request.error(request, :extract_object, "multiple objects in graph")
      end
    else
      request
    end
  end

  @spec ensure_correct_actor(Request.t()) :: Request.t()
  defp ensure_correct_actor(%Request{} = request) do
    case request.assigns.activity[:base_subject][AS.actor()] do
      nil ->
        request
        |> Request.assign(
          :activity,
          request.assigns.activity
          |> RDF.FragmentGraph.add(AS.actor(), User.actor_url(request.user))
        )

      [actor_in_activity] ->
        if actor_in_activity != User.actor_url(request.user) do
          Request.error(
            request,
            :ensure_correct_actor,
            "actor set in activity does not match user"
          )
        else
          request
        end

      _ ->
        Request.error(request, :ensure_correct_actor, "multiple actors in activity")
    end
  end

  defp ensure_no_bcc(%Request{} = request) do
    cond do
      request.assigns.activity[:base_subject][AS.bcc()] ->
        Request.error(request, :ensure_no_bcc, "bcc is not supported")

      request.assigns.activity[:base_subject][AS.bto()] ->
        Request.error(request, :ensure_no_bcc, "bto is not supported")

      true ->
        request
    end
  end

  defp get_all(container, keys, default) do
    Enum.map(keys, &Access.get(container, &1, default))
  end

  defp extract_recipients(%Request{} = request) do
    recipients =
      request.assigns.activity[:base_subject]
      |> get_all([AS.to(), AS.bto(), AS.cc(), AS.bcc(), AS.audience()], [])
      |> Enum.concat()

    request
    |> Request.assign(:recipients, recipients)
  end

  defp insert_object(%Request{} = request) do
    if RDF.iri(AS.Create) in request.assigns.activity[:base_subject][RDF.type()] do
      request
      |> Request.insert(:object, request.assigns.object |> Object.new() |> Object.changeset(),
        on_conflict: :nothing
      )
    else
      request
    end
  end

  defp insert_activity_object(%Request{} = request) do
    request
    |> Request.insert(
      :activity_object,
      request.assigns.activity |> Object.new() |> Object.changeset(),
      on_conflict: :nothing
    )
  end

  @spec insert_activity(Request.t()) :: Request.t()
  defp insert_activity(%Request{assigns: %{object: object}} = request) do
    request
    |> Request.insert(
      :activity,
      Activity.changeset(%Activity{}, %{
        actor: User.actor_url(request.user),
        recipients: request.assigns.recipients,
        activity_object_id: request.assigns.activity.base_subject,
        object_id: request.assigns.object.base_subject
      })
    )
  end

  defp insert_activity(%Request{} = request) do
    request
    |> Request.insert(
      :activity,
      Activity.changeset(%Activity{}, %{
        actor: User.actor_url(request.user),
        recipients: request.assigns.recipients,
        activity_object_id: request.assigns.activity.base_subject
      })
    )
  end
end
