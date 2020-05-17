defmodule CPub.Web.ObjectController do
  use CPub.Web, :controller

  alias CPub.{Object, Repo}

  action_fallback CPub.Web.FallbackController

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(%Plug.Conn{assigns: %{id: object_id}} = conn, _params) do
    object = Repo.get!(Object, object_id)

    conn
    |> put_view(RDFView)
    |> render(:show, data: object.data)
  end
end
