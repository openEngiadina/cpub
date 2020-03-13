defmodule CPub.Web.RDFView do
  @moduledoc """
  A generic view for anything that implements the `RDF.Data` protocol.
  """
  use CPub.Web, :view

  @spec render(String.t(), map) :: String.t() | map
  def render("show.json", %{data: data}) do
    RDF.JSON.Encoder.from_rdf!(data)
  end

  def render("show.ttl", %{data: data}) do
    RDF.Turtle.Encoder.encode!(data)
  end
end
