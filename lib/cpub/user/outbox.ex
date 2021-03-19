# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.User.Outbox do
  @moduledoc """
  A `CPub.User`s outbox that can be used to post ActivityStream activities.
  """

  alias CPub.ActivityPub
  alias CPub.DB
  alias CPub.User

  import RDF.Sigils
  alias RDF.FragmentGraph

  alias CPub.NS.ActivityStreams, as: AS
  alias RDF.NS.RDFS

  @activity_streams RDF.Turtle.read_file!("./priv/vocabs/activitystreams2.ttl")

  # Extract the activity from the input graph
  defp extract_activity(graph) do
    case [
           {:activity_type?, RDFS.subClassOf(), AS.Activity},
           {:activity_id?, RDF.type(), :activity_type?}
         ]
         |> RDF.Query.execute(RDF.Data.merge(graph, @activity_streams)) do
      {:ok, [%{activity_id: activity_id, activity_type: type}]} ->
        {:ok, type,
         FragmentGraph.new(activity_id)
         |> FragmentGraph.add(graph)
         |> FragmentGraph.finalize()}

      _ ->
        {:error, :no_activity_to_post}
    end
  end

  # Helper to replace occurence of a specific object in a FragmentGraph
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

  # Extract object from activity
  def extract_object(activity, graph) do
    case activity[:base_subject][AS.object()] do
      [%RDF.IRI{} = object_id] ->
        with object <-
               FragmentGraph.new(object_id)
               |> FragmentGraph.add(graph)
               |> FragmentGraph.finalize() do
          {:ok, object,
           activity |> replace_object_in_fragment_graph(object_id, object.base_subject)}
        end

      _ ->
        {:error, :could_not_extract_object}
    end
  end

  defp get_all(container, keys, default) do
    Enum.map(keys, &Access.get(container, &1, default))
  end

  # Extract recipients from activity
  defp extract_recipients(activity) do
    activity[:base_subject]
    |> get_all([AS.to(), AS.bto(), AS.cc(), AS.bcc(), AS.audience()], [])
    |> Enum.concat()
  end

  @doc """
  Post activity in `graph` on behalf of `user`.
  """
  def post(%User{} = user, %RDF.Graph{} = graph) do
    DB.transaction(fn ->
      with {:ok, type, activity} <- extract_activity(graph),
           {:ok, activity} <- perform_activity_side_effec(type, activity, graph),
           {:ok, activity_read_capability} <- CPub.ERIS.put(activity),
           :ok <- DB.Set.add(user.outbox, activity_read_capability),
           recipients <- extract_recipients(activity) do
        {activity_read_capability,
         recipients
         |> Map.new(fn recipient ->
           {recipient, ActivityPub.Delivery.deliver(recipient, activity_read_capability)}
         end)}
      end
    end)
  end

  # Perform ActivityPub side effects

  # Create
  defp perform_activity_side_effec(
         ~I<https://www.w3.org/ns/activitystreams#Create>,
         activity,
         graph
       ) do
    with {:ok, object, activity} <- extract_object(activity, graph),
         {:ok, _} <- CPub.ERIS.put(object) do
      {:ok, activity}
    end
  end
end
