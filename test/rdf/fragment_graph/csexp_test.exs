# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.FragmentGraph.CSexpTest do
  use ExUnit.Case
  use ExUnitProperties

  alias RDF.FragmentGraph

  doctest RDF.FragmentGraph.CSexp

  property "encode -> decode" do
    check all(fragment_graph <- RDF.StreamData.fragment_graph()) do
      assert fragment_graph ==
               fragment_graph
               |> FragmentGraph.CSexp.encode()
               |> FragmentGraph.CSexp.decode(fragment_graph.base_subject)
    end
  end
end
