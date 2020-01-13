defmodule CPubWeb.ActivityPub.OutboxController do

  use CPubWeb, :controller

  alias CPub.ActivityPub

  action_fallback CPubWeb.FallbackController

  def read_rdf_body(conn, opts \\ []) do
    with {:ok, body, conn} <- read_body(conn),
         {:ok, data} <- body |> RDF.Turtle.Decoder.decode(opts) do
      {:ok, data, conn}
    end
  end

  def post(conn, _params) do
    with user <- conn.assigns.user,
         activity_id <- CPub.ID.generate(type: :activity),
         {:ok, data, conn} <- read_rdf_body(conn, base_iri: activity_id),
         {:ok, %{activity: activity}} <- ActivityPub.create_activity(activity_id, data, user)
      do
      conn
      |> put_resp_header("Location", activity.id |> RDF.IRI.to_string)
      |> send_resp(:created, "")
    end
  end

end
