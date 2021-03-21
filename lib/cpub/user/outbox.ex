# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.User.Outbox do
  @moduledoc """
  A `CPub.User`s outbox that can be used to post ActivityStream activities.
  """

  import RDF.Sigils

  alias RDF.FragmentGraph
  alias RDF.Graph
  alias RDF.IRI
  alias RDF.NS.RDFS
  alias RDF.Statement

  alias CPub.ActivityPub
  alias CPub.DB
  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.User

  @activity_streams RDF.Turtle.read_file!("./priv/vocabs/activitystreams2.ttl")

  @doc """
  Extract object from activity
  """
  @spec extract_object(FragmentGraph.t(), Graph.t()) ::
          {:ok, FragmentGraph.t(), FragmentGraph.t()} | {:error, any}
  def extract_object(activity, graph) do
    case activity[:base_subject][AS.object()] do
      [%IRI{} = object_id] ->
        with object <-
               object_id
               |> FragmentGraph.new()
               |> FragmentGraph.add(graph)
               |> FragmentGraph.finalize() do
          {:ok, object,
           replace_object_in_fragment_graph(activity, object_id, object.base_subject)}
        end

      _ ->
        {:error, :could_not_extract_object}
    end
  end

  # Extract the activity from the input graph
  @spec extract_activity(Graph.t()) :: {:ok, IRI.t(), FragmentGraph.t()} | {:error, any}
  defp extract_activity(graph) do
    case [
           {:activity_type?, RDFS.subClassOf(), AS.Activity},
           {:activity_id?, RDF.type(), :activity_type?}
         ]
         |> RDF.Query.execute(RDF.Data.merge(graph, @activity_streams)) do
      {:ok, [%{activity_id: activity_id, activity_type: type}]} ->
        {:ok, type,
         activity_id
         |> FragmentGraph.new()
         |> FragmentGraph.add(graph)
         |> FragmentGraph.finalize()}

      _ ->
        {:error, :no_activity_to_post}
    end
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

  @spec get_all(RDF.Description.t(), [IRI.t()], [Statement.object()]) :: [Statement.object()]
  defp get_all(container, keys, default) do
    Enum.map(keys, &Access.get(container, &1, default))
  end

  # Extract recipients from activity
  @spec extract_recipients(FragmentGraph.t()) :: [Statement.object()]
  defp extract_recipients(activity) do
    activity[:base_subject]
    |> get_all([AS.to(), AS.bto(), AS.cc(), AS.bcc(), AS.audience()], [])
    |> Enum.concat()
  end

  @doc """
  Post activity in `graph` on behalf of `user`.
  """
  @spec post(User.t(), Graph.t()) :: {:ok, {ERIS.ReadCapability.t(), map}} | {:error, any}
  def post(%User{} = user, %Graph{} = graph) do
    DB.transaction(fn ->
      with {:ok, type, activity} <- extract_activity(graph),
           {:ok, activity} <- perform_activity_side_effec(type, activity, graph),
           {:ok, activity_read_capability} <- CPub.ERIS.put(activity),
           :ok <- DB.Set.add(user.outbox, activity_read_capability),
           recipients <- extract_recipients(activity) do
        {activity_read_capability,
         Map.new(recipients, fn recipient ->
           {recipient, ActivityPub.Delivery.deliver(recipient, activity_read_capability)}
         end)}
      end
    end)
  end

  # Perform ActivityPub side effects

  # Create
  @spec perform_activity_side_effec(IRI.t(), FragmentGraph.t(), Graph.t()) ::
          {:ok, FragmentGraph.t()}
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
