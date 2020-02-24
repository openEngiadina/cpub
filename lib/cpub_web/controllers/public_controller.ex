defmodule CPubWeb.PublicController do
  use CPubWeb, :controller

  action_fallback CPubWeb.FallbackController

  def get_public(conn, _params) do
    data =
      CPub.Public.get_public()
      |> Enum.map(&CPub.Activity.to_rdf/1)
      |> Enum.reduce(RDF.Graph.new(), &RDF.Data.merge(&1, &2))

    conn
    |> put_view(RDFView)
    |> render(:show, data: data)
  end
end
