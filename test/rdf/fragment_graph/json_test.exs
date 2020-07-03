defmodule RDF.FragmentGraph.JSONTest do
  use ExUnit.Case
  use ExUnitProperties

  alias RDF.FragmentGraph

  doctest RDF.FragmentGraph.JSON

  property "encode -> decode" do
    check all(fragment_graph <- RDF.StreamData.fragment_graph()) do
      assert fragment_graph ==
               fragment_graph
               |> FragmentGraph.JSON.from_rdf!()
               |> Jason.encode!()
               |> Jason.decode!()
               |> FragmentGraph.JSON.to_rdf!()
    end
  end
end
