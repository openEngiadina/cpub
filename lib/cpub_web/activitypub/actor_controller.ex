defmodule CPubWeb.ActivityPub.ActorController do
  use CPubWeb, :controller

  alias CPub.ActivityPub

  def show(conn, _params) do
    actor = ActivityPub.get_actor!(conn.assigns[:id])
    conn
    |> put_view(ObjectView)
    |> render(:show, object: actor)
  end

end
