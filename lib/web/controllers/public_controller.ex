defmodule CPub.Web.PublicController do
  use CPub.Web, :controller

  alias CPub.{Activity, Public}

  action_fallback CPub.Web.FallbackController

  @spec get_public(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_public(conn, _params) do
    data =
      Public.get_public()
      |> Activity.as_container(conn.assigns[:id])

    # |> Enum.map(&Activity.to_rdf/1)
    # |> Enum.reduce(Graph.new(), &Data.merge(&1, &2))

    conn
    |> put_view(RDFView)
    |> render(:show, data: data)
  end
end
