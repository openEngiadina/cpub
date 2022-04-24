# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule JSON.LD.Encoder.CPub do
  @moduledoc """
  JSON-LD encoder which supports `RDF.FragmentGraph` and encodes with compaction.
  """

  alias JSON.LD.DocumentLoader
  alias JSON.LD.Encoder

  alias CPub.NS

  @context %{"@context" => [NS.activity_streams_url(), NS.litepub_url(), NS.ldp_url()]}
  @document_loader DocumentLoader.CPub

  @spec compact_encode!(Encoder.input() | RDF.FragmentGraph.t()) :: String.t()
  def compact_encode!(%RDF.FragmentGraph{} = data) do
    {json_ld, properties} =
      data
      |> RDF.Data.descriptions()
      |> Enum.map(&compact_json_ld/1)
      |> List.pop_at(0)

    id = json_ld["id"]

    json_ld =
      Enum.reduce(properties, json_ld, fn property, acc ->
        key = String.trim_leading(property["id"], "#{id}#")
        Map.put(acc, key, Map.drop(property, ["@context", "id"]))
      end)

    Jason.encode!(json_ld)
  end

  def compact_encode!(data) do
    data
    |> compact_json_ld()
    |> Jason.encode!()
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
