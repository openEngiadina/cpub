# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.SkolemTest do
  use ExUnit.Case
  use ExUnitProperties

  doctest RDF.Skolem

  property "Skolemized graph does not contain any blank nodes" do
    check all(graph <- RDF.StreamData.graph()) do
      assert graph
             |> RDF.Skolem.skolemize_graph()
             |> RDF.Data.resources()
             |> Enum.filter(&RDF.bnode?/1)
             |> Enum.empty?()
    end
  end
end
