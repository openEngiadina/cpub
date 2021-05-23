# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule JSON.LD.Encoder.ActivityPub do
  @moduledoc """
  JSON-LD encoder which supports `RDF.FragmentGraph`, encodes with compaction
  and replaces objects' URIs with their content like ActivityPub specification
  requires.
  """

  alias JSON.LD.DocumentLoader
  alias JSON.LD.Encoder
  alias RDF.Query.ActivityStreams

  alias CPub.NS
  alias CPub.NS.ActivityStreams, as: AS

  @context %{"@context" => [NS.activity_streams_url(), NS.litepub_url(), NS.ldp_url()]}
  @document_loader DocumentLoader.CPub

  @spec compact_encode!(Encoder.input() | RDF.FragmentGraph.t()) :: String.t()
  def compact_encode!(%RDF.FragmentGraph{} = fg) do
    case ActivityStreams.type(fg) do
      {:collection, _} ->
        do_compact_encode!(fg, :collection)

      {:activity_with_object_uri, _} ->
        do_compact_encode!(fg, :activity)

      _ ->
        do_compact_encode!(fg, :object)
    end
    |> Jason.encode!()
  end

  def compact_encode!(%RDF.Graph{} = graph) do
    graph
    |> RDF.FragmentGraph.new()
    |> compact_encode!()
  end

  @spec do_compact_encode!(Encoder.input() | RDF.FragmentGraph.t(), atom) :: map
  defp do_compact_encode!(%RDF.FragmentGraph{} = collection_fg, :collection) do
    with collection <- do_compact_encode!(collection_fg, :object),
         items <-
           collection_fg.statements[AS.items()]
           |> MapSet.to_list()
           |> Enum.map(
             &with {:ok, fg} <- CPub.ERIS.get_rdf(&1), do: do_compact_encode!(fg, :activity)
           ) do
      collection
      # AS.items
      |> Map.put("items", items)
      # LDP.member
      |> Map.put("member", items)
    end
  end

  defp do_compact_encode!(%RDF.FragmentGraph{} = activity_fg, :activity) do
    case ConCache.get(:fragment_graphs, activity_fg.base_subject) do
      nil ->
        fg_to_cache =
          with [urn] <- MapSet.to_list(activity_fg.statements[AS.object()]) do
            case CPub.ERIS.get_rdf(urn) do
              {:ok, object_fg} ->
                with object <- object_fg |> do_compact_encode!(:object) |> Map.delete("@context"),
                     activity <- do_compact_encode!(activity_fg, :object) do
                  # AS.object
                  Map.put(activity, "object", object)
                end

              {:error, _} ->
                do_compact_encode!(activity_fg, :object)
            end
          end

        :ok = ConCache.put(:fragment_graphs, activity_fg.base_subject, fg_to_cache)

        fg_to_cache

      cached_fg ->
        cached_fg
    end
  end

  defp do_compact_encode!(%RDF.FragmentGraph{} = object_fg, :object) do
    {json_ld, properties} =
      object_fg
      |> RDF.Data.descriptions()
      |> Enum.map(&compact_json_ld/1)
      |> List.pop_at(0)

    id = json_ld["id"]

    Enum.reduce(properties, json_ld, fn property, acc ->
      key = String.trim_leading(property["id"], "#{id}#")
      Map.put(acc, key, Map.drop(property, ["@context", "id"]))
    end)
  end

  @spec compact_json_ld(Encoder.input() | RDF.Description.t()) :: map
  @dialyzer {:nowarn_function, compact_json_ld: 1}
  defp compact_json_ld(data) do
    data
    |> Encoder.encode!(expand_context: @context, document_loader: @document_loader)
    |> Jason.decode!()
    |> JSON.LD.compact(@context, document_loader: @document_loader)
  end
end
