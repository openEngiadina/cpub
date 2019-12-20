defmodule CPubWeb.LDP.RDFSourceView do
  use CPubWeb, :view

  alias RDF.Turtle

  def render("index.json", %{rdf_sources: rdf_sources}) do
    Enum.reduce(rdf_sources, RDF.Graph.new, fn rdf_source, graph ->
      graph
      |> RDF.Graph.add(rdf_source.data)
    end)
    |> RDF.JSON.Encoder.from_rdf!
  end

  def render("index.ttl", %{rdf_sources: rdf_sources}) do
    Enum.reduce(rdf_sources, RDF.Graph.new, fn rdf_source, graph ->
      graph
      |> RDF.Graph.add(rdf_source.data)
    end)
    |> Turtle.Encoder.encode!
  end

  def render("show.json", %{rdf_source: rdf_source}) do
    rdf_source.data
    |> RDF.JSON.Encoder.from_rdf!
  end

  def render("show.ttl", %{rdf_source: rdf_source}) do
    rdf_source.data
    |> Turtle.Encoder.encode!
  end

end
