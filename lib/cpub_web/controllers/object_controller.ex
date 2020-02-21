defmodule CPubWeb.ObjectController do
  use CPubWeb, :controller

  alias CPub.Object

  action_fallback CPubWeb.FallbackController

  def show(conn, _params) do
    object = CPub.Repo.get!(Object, conn.assigns[:id])

    conn
    |> put_view(RDFView)
    |> render(:show, data: object.data)
  end
end
