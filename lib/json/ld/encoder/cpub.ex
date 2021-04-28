# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule JSON.LD.Encoder.CPub do
  @moduledoc """
  JSON-LD encoder which supports `RDF.FragmentGraph`.
  """

  alias JSON.LD.DocumentLoader
  alias JSON.LD.Encoder

  alias CPub.NS

  @spec encode!(RDF.FragmentGraph.t(), Enum.t()) :: String.t()
  def encode!(%RDF.FragmentGraph{} = data, _opts \\ []) do
    {json_ld, properties} =
      data
      |> RDF.Data.descriptions()
      |> Enum.map(&to_compact_json_ld/1)
      |> List.pop_at(0)

    id = json_ld["id"]

    json_ld =
      Enum.reduce(properties, json_ld, fn property, acc ->
        key = String.trim_leading(property["id"], "#{id}#")
        Map.put(acc, key, Map.drop(property, ["@context", "id"]))
      end)

    Jason.encode!(json_ld)
  end

  @spec to_compact_json_ld(RDF.Description.t()) :: map
  @dialyzer {:nowarn_function, to_compact_json_ld: 1}
  defp to_compact_json_ld(%RDF.Description{} = data) do
    data
    |> Encoder.encode!(
      expand_context: %{"@context" => [NS.activity_streams_url(), NS.litepub_url()]},
      document_loader: DocumentLoader.CPub
    )
    |> Jason.decode!()
    |> JSON.LD.compact(
      %{"@context" => [NS.activity_streams_url(), NS.litepub_url()]},
      document_loader: DocumentLoader.CPub
    )
  end
end
