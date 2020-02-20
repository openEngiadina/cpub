defmodule CPubWeb.UserController do
  use CPubWeb, :controller

  action_fallback CPubWeb.FallbackController

  def show(conn, _params) do
    user = CPub.Repo.get!(CPub.User, conn.assigns[:id])
    conn
    |> put_view(RDFView)
    |> render(:show, data: user.profile)
  end


  # TODO move code to create an actor to a create user endpoint
  # def create(conn, _params) do
  #   with id <- CPub.ID.generate(type: :actor),
  #        {:ok, data, conn} <- read_rdf_body(conn, base_iri: id),
  #        description <- data[id],
  #        {:ok, %{actor: actor}} <- ActivityPub.create_actor(description: description)
  #     do
  #     conn
  #     |> put_resp_header("Location", actor.id |> RDF.IRI.to_string)
  #     |> send_resp(:created, "")
  #   end
  # end

end
