defmodule CPubWeb.ObjectView do
  use CPubWeb, :view

  alias CPubWeb.ObjectView

  alias RDF.IRI

  def render("index.json", %{objects: objects}) do
    render_many(objects, ObjectView, "object.json")
  end

  def render("show.json", %{object: object}) do
    render_one(object, ObjectView, "object.json")
  end

  def render("object.json", %{object: object}) do
    %{id: object.id |> IRI.to_string }
  end

end
