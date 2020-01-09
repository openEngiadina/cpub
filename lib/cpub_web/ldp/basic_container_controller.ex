defmodule CPubWeb.LDP.BasicContainerController do
  use CPubWeb, :controller

  alias CPub.LDP.BasicContainer
  alias CPub.Repo

  def show(conn, _params) do
    user = Map.get(conn.assigns, :user, nil)
    container =
      Repo.get_resource(BasicContainer,
        conn.assigns.id,
        user)

    conn
    |> put_view(RDFSourceView)
    |> render(:show, rdf_source: container)
  end

end
