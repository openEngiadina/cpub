defmodule CPubWeb.PublicController do
  use CPubWeb, :controller

  alias CPub.{Activity, Public}
  alias RDF.{Data, Graph}

  action_fallback CPubWeb.FallbackController

  def get_public(conn, _params) do
    data =
      Public.get_public()
      |> Enum.map(&Activity.to_rdf/1)
      |> Enum.reduce(Graph.new(), &Data.merge(&1, &2))

    conn
    |> put_view(RDFView)
    |> render(:show, data: data)
  end
end
