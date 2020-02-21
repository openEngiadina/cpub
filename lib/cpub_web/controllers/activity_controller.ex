defmodule CPubWeb.ActivityController do
  use CPubWeb, :controller

  alias CPub.Activity

  action_fallback CPubWeb.FallbackController

  def show(conn, _params) do
    activity = CPub.Repo.get!(Activity, conn.assigns[:id])
    conn
    |> put_view(RDFView)
    |> render(:show, data: activity.data)
  end

end
