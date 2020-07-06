defmodule CPub.Web.ObjectController do
  use CPub.Web, :controller

  alias CPub.Object

  action_fallback CPub.Web.FallbackController

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(%Plug.Conn{} = conn, %{"id" => id_string}) do
    with {:ok, id} <- RDF.UUID.cast(id_string),
         {:ok, object} <- Repo.get_one(Object, id) do
      conn
      |> put_view(RDFView)
      |> render(:show, data: object.content)
    end
  end
end
