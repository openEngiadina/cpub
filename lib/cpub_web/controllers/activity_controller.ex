defmodule CPubWeb.ActivityController do
  use CPubWeb, :controller

  alias CPub.{Activity, Repo}

  action_fallback CPubWeb.FallbackController

  def show(conn, _params) do
    activity =
      Activity
      |> Repo.get!(conn.assigns[:id])
      |> Repo.preload(:object)

    conn
    |> put_view(RDFView)
    |> render(:show, data: Activity.to_rdf(activity))
  end
end
