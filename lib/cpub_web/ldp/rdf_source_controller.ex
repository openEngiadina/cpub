defmodule CPubWeb.LDP.RDFSourceController do
  use CPubWeb, :controller

  alias CPub.LDP

  action_fallback CPubWeb.FallbackController

  def index(conn, _params) do
    rdf_sources = LDP.list_rdf_source()
    render(conn, :index, rdf_sources: rdf_sources)
  end

  def show(conn, %{"id" => _}) do
    rdf_source = LDP.get_rdf_source!(conn.assigns[:id])
    render(conn, :show, rdf_source: rdf_source)
  end

end
