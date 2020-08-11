defmodule RDF.JSONTest do
  use ExUnit.Case
  use ExUnitProperties

  alias RDF.JSON.{Decoder, Encoder}

  doctest RDF.JSON

  property "encode -> decode" do
    check all(graph <- RDF.StreamData.graph()) do
      assert graph ==
               graph
               |> Encoder.encode!()
               |> Jason.encode!()
               |> Jason.decode!()
               |> Decoder.decode!()
    end
  end
end
