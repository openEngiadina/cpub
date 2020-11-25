# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.Skolem do
  @moduledoc """
  Blank node Skolemization.
  """

  @doc """
  Skolemize some `RDF.Data` and return as `RDF.Graph`
  """
  @spec skolemize_graph(RDF.Description.t() | RDF.Graph.t() | RDF.Dataset.t()) :: RDF.Graph.t()
  def skolemize_graph(data) do
    bnode_mapping = make_bnode_mapping(data)

    data
    |> RDF.Data.statements()
    |> Enum.map(fn statement -> replace_in_statement(statement, bnode_mapping) end)
    |> RDF.Graph.new()
  end

  @spec make_bnode_mapping(RDF.Description.t() | RDF.Graph.t() | RDF.Dataset.t()) :: map
  defp make_bnode_mapping(data) do
    RDF.Data.resources(data)
    |> Enum.filter(&RDF.bnode?/1)
    |> Enum.map(fn bnode -> {bnode, RDF.UUID.generate()} end)
    |> Map.new()
  end

  @spec replace_in_statement(RDF.Statement.t(), map) :: tuple
  defp replace_in_statement({s, p, o}, mapping) do
    {Map.get(mapping, s, s), p, Map.get(mapping, o, o)}
  end

  defp replace_in_statement({g, s, p, o}, mapping) do
    {g, Map.get(mapping, s, s), p, Map.get(mapping, o, o)}
  end
end
