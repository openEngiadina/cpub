defmodule CPubWeb.ObjectController do
  use CPubWeb, :controller

  alias CPub.Objects

  alias CPub.ID

  action_fallback CPubWeb.FallbackController

  def index(conn, _params) do
    objects = Objects.list_objects()
    render(conn, :index, objects: objects)
  end

  def show(conn, %{"id" => _}) do
    object = Objects.get_object!(conn.assigns[:id])
    render(conn, :show, object: object)
  end

end
