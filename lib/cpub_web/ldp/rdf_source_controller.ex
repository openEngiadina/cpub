defmodule CPubWeb.LDP.RDFSourceController do
  use CPubWeb, :controller

  alias CPub.Repo
  alias CPub.LDP.RDFSource

  action_fallback CPubWeb.FallbackController

  def index(conn, _params) do
    rdf_sources = Repo.all_resources(RDFSource, conn.assigns.user)
    render(conn, :index, rdf_sources: rdf_sources)
  end

  def show(conn, %{"id" => _}) do
    rdf_source = Repo.get_resource(RDFSource, conn.assigns.id, conn.assigns.user)
    render(conn, :show, rdf_source: rdf_source)
  end

end
