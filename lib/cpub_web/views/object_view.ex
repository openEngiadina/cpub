defmodule CPubWeb.ObjectView do
  use CPubWeb, :view

  alias CPubWeb.ObjectView

  alias RDF.Turtle

  def render("index.json", %{objects: objects}) do
    Enum.reduce(objects, RDF.Graph.new, fn object, graph ->
      graph
      |> RDF.Graph.add(object.data)
    end)
    |> RDF.JSON.Encoder.from_rdf!
  end

  def render("index.ttl", %{objects: objects}) do
    Enum.reduce(objects, RDF.Graph.new, fn object, graph ->
      graph
      |> RDF.Graph.add(object.data)
    end)
    |> Turtle.Encoder.encode!
  end

  def render("show.json", %{object: object}) do
    object.data
    |> RDF.JSON.Encoder.from_rdf!
  end

  def render("show.ttl", %{object: object}) do
    object.data
    |> Turtle.Encoder.encode!
  end

end
