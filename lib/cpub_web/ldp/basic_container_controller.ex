defmodule CPubWeb.LDP.BasicContainerController do
  use CPubWeb, :controller

  alias CPub.LDP

  def show(conn, _params) do
    container = LDP.get_basic_container!(conn.assigns[:id])
    conn
    |> put_view(RDFSourceView)
    |> render(:show, rdf_source: container)
  end

end
