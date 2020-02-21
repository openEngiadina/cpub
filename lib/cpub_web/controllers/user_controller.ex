defmodule CPubWeb.UserController do
  use CPubWeb, :controller

  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.ActivityPub

  action_fallback CPubWeb.FallbackController

  def show(conn, _params) do
    user = CPub.Repo.get!(CPub.User, conn.assigns[:id])
    conn
    |> put_view(RDFView)
    |> render(:show, data: user.profile)
  end

  defp read_rdf_body(conn, opts \\ []) do
    with {:ok, body, conn} <- read_body(conn),
         {:ok, data} <- body |> RDF.Turtle.Decoder.decode(opts) do
      {:ok, data, conn}
    end
  end

  def post_to_outbox(conn, _params) do
    with user <- conn.assigns.user,
         activity_id <- CPub.ID.generate(type: :activity),
         {:ok, data, conn} <- read_rdf_body(conn, base_iri: activity_id),
         {:ok, %{activity: activity}} <- ActivityPub.handle_activity(activity_id, data, user)
      do
      conn
      |> put_resp_header("Location", activity.id |> RDF.IRI.to_string)
      |> send_resp(:created, "")
    end
  end

  def get_inbox(conn, _params) do
    user = conn.assigns.user

    data = CPub.User.get_inbox(user)
    |> Enum.map(&CPub.Activity.to_rdf/1)
    |> Enum.reduce(RDF.Graph.new, &(RDF.Data.merge(&1,&2)))

    conn
    |> put_view(RDFView)
    |> render(:show, data: data)
  end

  def get_outbox(conn, _params) do
    user = conn.assigns.user

    data = CPub.User.get_outbox(user)
    |> Enum.map(&CPub.Activity.to_rdf/1)
    |> Enum.reduce(RDF.Graph.new, &(RDF.Data.merge(&1,&2)))

    conn
    |> put_view(RDFView)
    |> render(:show, data: data)
  end

end
