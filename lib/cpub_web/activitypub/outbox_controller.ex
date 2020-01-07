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

  def post(conn, %{"user_id" => actor_id}) do
    with _actor_id <- CPub.ID.merge_with_base_url("actor/" <> actor_id),
         activity_id <- CPub.ID.generate(type: :activity),
         {:ok, data, conn} <- read_rdf_body(conn, base_iri: activity_id),
         # TODO make sure actor field is properly set in new activity
         {:ok, %{activity: _activity}} <- ActivityPub.create_activity(activity_id, data)
      do
      conn
      |> put_resp_header("Location", activity_id |> RDF.IRI.to_string)
      |> send_resp(:created, "")
    end
  end

end
