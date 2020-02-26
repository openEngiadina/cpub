defmodule RDF.JSONTest do
  use ExUnit.Case
  use ExUnitProperties

  doctest RDF.JSON

  property "encode -> decode" do
    check all(graph <- RDF.StreamData.graph()) do
      assert graph ==
               graph
               |> RDF.JSON.Encoder.encode!()
               |> RDF.JSON.Decoder.decode!()
    end
  end
end
