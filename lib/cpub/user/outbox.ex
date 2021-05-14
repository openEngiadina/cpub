# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.User.Outbox do
  @moduledoc """
  A `CPub.User`s outbox that can be used to post ActivityStream activities.
  """

  import RDF.Sigils

  alias RDF.Description
  alias RDF.FragmentGraph
  alias RDF.Graph
  alias RDF.IRI
  alias RDF.Literal
  alias RDF.NS.RDFS
  alias RDF.Statement

  alias CPub.ActivityPub
  alias CPub.DB
  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.User

  alias CPub.Web.Path

  @type rdf_query_result :: {:ok, [%{:atom => IRI.t()}]}

  @type recipients_map :: %{IRI.t() => Statement.object()}

  @activity_streams RDF.Turtle.read_file!("./priv/vocabs/activitystreams2.ttl")

  @create_activity ~I<https://www.w3.org/ns/activitystreams#Create>
  @update_activity ~I<https://www.w3.org/ns/activitystreams#Update>

  @activity_with_object_bgp [
    {:activity_id?, :a, :activity_type?},
    {:activity_type?, RDFS.subClassOf(), AS.Activity},
    {:activity_id?, AS.object(), :object_id?},
    {:object_id?, :a, :object_type?}
  ]

  @activity_with_object_uri_bgp [
    {:activity_id?, :a, :activity_type?},
    {:activity_type?, RDFS.subClassOf(), AS.Activity},
    {:activity_id?, AS.object(), :object_uri?}
  ]

  @doc """
  Post activity in `graph` on behalf of `actor`.
  """
  @spec post(User.t(), Graph.t()) :: {:ok, {ERIS.ReadCapability.t(), map}} | {:error, any}
  def post(%User{} = actor, %Graph{} = graph) do
    DB.transaction(fn ->
      with {:ok, activity_type, activity, object, recipients} <-
             extract_or_create_activity(graph, actor),
           {:ok, _object} <- perform_activity_side_effect(activity_type, object),
           {:ok, activity_read_capability} <- CPub.ERIS.put(activity),
           :ok <- DB.Set.add(actor.outbox, activity_read_capability) do
        {activity_read_capability,
         ActivityPub.Delivery.deliver(recipients, activity_read_capability)}
      else
        {:error, reason} ->
          DB.abort(reason)
      end
    end)
  end

  # Extract any activity or an object for creation without a surrounding activity
  @spec extract_or_create_activity(Graph.t(), User.t()) ::
          {:ok, RDF.IRI.t(), FragmentGraph.t(), FragmentGraph.t(), [String.t()]} | {:error, any}
  defp extract_or_create_activity(%Graph{} = graph, %User{} = actor) do
    @activity_with_object_bgp
    |> RDF.Query.execute(RDF.Data.merge(graph, @activity_streams))
    |> extract_activity_with_object(graph, actor)
  end

  # Extract the `Create` activity with object's properties
  @spec extract_activity_with_object(rdf_query_result, Graph.t(), User.t()) ::
          {:ok, RDF.IRI.t(), FragmentGraph.t(), FragmentGraph.t(), [String.t()]} | {:error, any}
  defp extract_activity_with_object(
         {:ok,
          [%{activity_id: activity_id, activity_type: @create_activity, object_id: object_id}]},
         %Graph{} = activity_graph,
         %User{} = actor
       ) do
    now = now()
    actor_url = Path.user(actor)

    object =
      activity_graph[object_id]
      |> Description.put({AS.attributedTo(), actor_url |> RDF.iri()})
      |> Description.put({AS.published(), now})
      |> add_actor_followers_to_recipients(actor)

    activity =
      activity_graph[activity_id]
      |> Description.put({AS.actor(), actor_url |> RDF.iri()})
      |> Description.put({AS.published(), now})

    object_recipients = extract_recipients(object)
    activity_recipients = extract_recipients(activity)

    recipients =
      Map.merge(object_recipients, activity_recipients, fn _k, v1, v2 ->
        (List.wrap(v1) ++ List.wrap(v2)) |> MapSet.new() |> MapSet.to_list()
      end)

    [object, activity] =
      Enum.map([object, activity], fn item ->
        item
        |> Description.put({AS.to(), recipients[AS.to()]})
        |> Description.put({AS.cc(), recipients[AS.cc()]})
        |> Description.put({AS.audience(), recipients[AS.audience()]})
        |> remove_hidden_recipients()
      end)

    object_fg = create_finalized_fragment_graph(object_id, object)

    activity_fg =
      activity_id
      |> create_finalized_fragment_graph(activity)
      |> replace_object_in_fragment_graph(object_id, object_fg.base_subject)

    recipients = list_recipients(recipients, actor_url)

    {:ok, AS.Create |> RDF.iri(), activity_fg, object_fg, recipients}
  end

  ## TODO: add support
  # Extract the `Update` activity with object's properties
  defp extract_activity_with_object({:ok, [%{activity_type: @update_activity}]}, _, _) do
    {:error, :not_supported}
  end

  # Any activities except of `Create` and `Update` should contain an object's URI
  defp extract_activity_with_object({:ok, [%{activity_type: _}]}, _, _) do
    {:error, :no_object_uri}
  end

  # Extract an activity with an object's URI
  defp extract_activity_with_object({:ok, []}, %Graph{} = graph, %User{} = actor) do
    @activity_with_object_uri_bgp
    |> RDF.Query.execute(RDF.Data.merge(graph, @activity_streams))
    |> extract_activity_with_object_uri(graph, actor)
  end

  # `Create` and `Update` activities should contain actual object's properties
  @spec extract_activity_with_object_uri(rdf_query_result, Graph.t(), User.t()) ::
          {:ok, RDF.IRI.t(), FragmentGraph.t(), FragmentGraph.t(), [String.t()]} | {:error, any}
  defp extract_activity_with_object_uri({:ok, [%{activity_type: activity_type}]}, _, _)
       when activity_type in [@create_activity, @update_activity] do
    {:error, :no_object}
  end

  ## TODO: add support
  # Extract an activity with an object's URI for the rest types of activities
  defp extract_activity_with_object_uri({:ok, [%{activity_id: _, object_uri: _}]}, _, _) do
    {:error, :not_supported}
  end

  # Extract an object for creation without a surrounding activity
  defp extract_activity_with_object_uri({:ok, []}, %Graph{} = graph, %User{} = actor) do
    create_activity(graph, actor)
  end

  # Surround an object with the `Create` activity
  @spec create_activity(Graph.t(), User.t()) ::
          {:ok, RDF.IRI.t(), FragmentGraph.t(), FragmentGraph.t(), [String.t()]} | {:error, any}
  defp create_activity(%Graph{} = object_graph, %User{} = actor) do
    now = now()
    [object_id] = Map.keys(object_graph.descriptions)
    activity_id = DB.Set.new()
    actor_url = Path.user(actor)

    object =
      object_graph[object_id]
      |> Description.put({AS.attributedTo(), actor_url |> RDF.iri()})
      |> Description.put({AS.published(), now})
      |> add_actor_followers_to_recipients(actor)

    recipients = extract_recipients(object)

    object = remove_hidden_recipients(object)
    object_fg = create_finalized_fragment_graph(object_id, object)

    create_activity = create_activity_object(activity_id, object_id, actor_url, now, recipients)

    create_activity_fg =
      activity_id
      |> create_finalized_fragment_graph(create_activity)
      |> replace_object_in_fragment_graph(object_id, object_fg.base_subject)

    recipients = list_recipients(recipients, actor_url)

    {:ok, AS.Create |> RDF.iri(), create_activity_fg, object_fg, recipients}
  end

  @spec get_all(Description.t(), [IRI.t()], [Statement.object()]) :: recipients_map
  defp get_all(container, keys, default) do
    Map.new(keys, &{&1, Access.get(container, &1, default)})
  end

  # Extract all recipients from an object
  @spec extract_recipients(Description.t()) :: recipients_map
  defp extract_recipients(object) do
    get_all(object, [AS.to(), AS.cc(), AS.bto(), AS.bcc(), AS.audience()], [])
  end

  # List de-duplicated recipients excluding an actor themselves
  @spec list_recipients(recipients_map, String.t()) :: [String.t()]
  defp list_recipients(recipients, actor_url) do
    recipients
    |> Map.values()
    |> List.flatten()
    # de-duplicate the recipient list
    |> MapSet.new()
    # exclude the actor themselves from the list
    |> MapSet.delete(actor_url)
    |> MapSet.to_list()
  end

  # Add actor's followers to the `to` property of an object
  @spec add_actor_followers_to_recipients(Description.t(), User.t()) :: Description.t()
  defp add_actor_followers_to_recipients(%Description{} = object, %User{} = actor) do
    actor_followers_iri = Path.user_followers(actor) |> RDF.iri()

    Description.put(
      object,
      {AS.to(),
       [actor_followers_iri | List.wrap(object[AS.to()])] |> MapSet.new() |> MapSet.to_list()}
    )
  end

  # Remove `bto` and `bcc` properties from an object
  @spec remove_hidden_recipients(Description.t()) :: Description.t()
  defp remove_hidden_recipients(%Description{} = object) do
    object
    |> Description.delete_predicates(AS.bto())
    |> Description.delete_predicates(AS.bcc())
  end

  @spec create_activity_object(IRI.t(), IRI.t(), String.t(), Literal.t(), recipients_map) ::
          Description.t()
  defp create_activity_object(activity_id, object_id, actor_url, now, recipients) do
    activity_id
    |> Description.new()
    |> Description.put({RDF.type(), AS.Create})
    |> Description.put({AS.actor(), actor_url |> RDF.iri()})
    |> Description.put({AS.published(), now})
    |> Description.put({AS.object(), object_id})
    |> Description.put({AS.to(), recipients[AS.to()]})
    |> Description.put({AS.cc(), recipients[AS.cc()]})
    |> Description.put({AS.audience(), recipients[AS.audience()]})
  end

  @spec create_finalized_fragment_graph(IRI.t(), Description.t()) :: FragmentGraph.t()
  defp create_finalized_fragment_graph(%IRI{} = object_id, %Description{} = object) do
    object_id
    |> FragmentGraph.new()
    |> FragmentGraph.add(Graph.new(object))
    |> FragmentGraph.finalize(&CPub.Magnet.fragment_graph_finalizer/1)
  end

  # Helper to replace occurence of a specific object in a FragmentGraph
  @spec replace_object_in_fragment_graph(FragmentGraph.t(), IRI.t(), IRI.t()) :: FragmentGraph.t()
  defp replace_object_in_fragment_graph(fg, from, to) do
    fg.base_subject
    |> FragmentGraph.new()
    |> FragmentGraph.add(
      fg
      |> RDF.Data.statements()
      |> Enum.map(fn {s, p, o} ->
        case o do
          ^from -> {s, p, to}
          _ -> {s, p, o}
        end
      end)
    )
  end

  @spec now :: Literal.t()
  defp now do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
    |> RDF.XSD.dateTime()
  end

  # Perform ActivityPub side effects

  # Create Activity
  @spec perform_activity_side_effect(IRI.t(), FragmentGraph.t()) :: {:ok, FragmentGraph.t()}
  defp perform_activity_side_effect(@create_activity, object) do
    with {:ok, _} <- CPub.ERIS.put(object), do: {:ok, object}
  end
end
