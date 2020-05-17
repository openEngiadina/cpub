defmodule CPub.Web.PublicController do
  use CPub.Web, :controller

  alias CPub.{Activity, Public}

  action_fallback CPub.Web.FallbackController

  @spec get_public(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_public(%Plug.Conn{assigns: %{id: public_id}} = conn, _params) do
    data =
      Public.get_public()
      |> Activity.as_container(public_id)

    # |> Enum.map(&Activity.to_rdf/1)
    # |> Enum.reduce(Graph.new(), &Data.merge(&1, &2))

    conn
    |> put_view(RDFView)
    |> render(:show, data: data)
  end
end
