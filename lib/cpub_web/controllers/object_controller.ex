defmodule CPubWeb.ObjectController do
  use CPubWeb, :controller

  alias CPub.Objects
  alias CPub.Objects.Object

  alias CPub.ID

  action_fallback CPubWeb.FallbackController

  def index(conn, _params) do
    objects = Objects.list_objects()
    render(conn, "index.json", objects: objects)
  end

  def show(conn, %{"id" => _}) do
    with {:ok, id} <- Plug.Conn.request_url(conn) |> ID.cast() do
      object = Objects.get_object!(id)
      render(conn, "show.json", object: object)
    end
  end

end
