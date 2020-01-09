defmodule CPubWeb.LDP.BasicContainerController do
  use CPubWeb, :controller

  alias CPub.LDP.BasicContainer
  alias CPub.Repo

  def show(conn, _params) do
    container =
      Repo.get_resource(BasicContainer,
        conn.assigns.id,
        conn.assigns.user)

    conn
    |> put_view(RDFSourceView)
    |> render(:show, rdf_source: container)
  end

end
