# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.Query.ActivityStreams do
  @moduledoc """
  Helpers to determine Activity Streams types.
  """

  alias RDF.NS.RDFS

  alias CPub.NS.ActivityStreams, as: AS

  @type type ::
          :activity_with_object
          | :activity_with_object_uri
          | :collection
          | :object

  @activity_streams RDF.Turtle.read_file!("./priv/vocabs/activitystreams2.ttl")

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

  @collection_bgp [
    {:collection_type?, RDFS.subClassOf(), AS.Collection},
    {:collection_id?, AS.items(), :collection_items?}
  ]

  @object_bgp [
    {:object_id?, :a, :object_type?},
    {:object_type?, RDFS.subClassOf(), AS.Object}
  ]

  @types_check_list [
    activity_with_object: @activity_with_object_bgp,
    activity_with_object_uri: @activity_with_object_uri_bgp,
    collection: @collection_bgp,
    object: @object_bgp
  ]

  @spec type(RDF.FragmentGraph.t() | RDF.Graph.t()) :: {type, %{atom => RDF.IRI.t()}}
  def type(%RDF.FragmentGraph{} = fragment_graph) do
    fragment_graph
    |> RDF.FragmentGraph.graph()
    |> type()
  end

  def type(%RDF.Graph{} = graph) do
    graph = RDF.Data.merge(graph, @activity_streams)

    Enum.reduce_while(@types_check_list, {:unknown, %{}}, fn {type, type_bgp}, acc ->
      case RDF.Query.execute(type_bgp, graph) do
        {:ok, [object]} when not (type in [:collection]) ->
          {:halt, {type, object}}

        {:ok, items} when type in [:collection] and length(items) > 0 ->
          {:halt, {type, Enum.map(items, & &1.collection_items)}}

        {:ok, []} ->
          {:cont, acc}
      end
    end)
  end
end
