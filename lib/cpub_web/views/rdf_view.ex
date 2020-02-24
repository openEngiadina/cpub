defmodule CPubWeb.RDFView do
  @moduledoc """
  A generic view for anything that implements the `RDF.Data` protocol.
  """
  use CPubWeb, :view

  def render("show.json", %{data: data}) do
    data
    |> RDF.JSON.Encoder.from_rdf!()
  end

  def render("show.ttl", %{data: data}) do
    data
    |> RDF.Turtle.Encoder.encode!()
  end
end
