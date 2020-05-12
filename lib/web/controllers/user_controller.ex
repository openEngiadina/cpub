defmodule CPub.Web.UserController do
  use CPub.Web, :controller

  alias CPub.{ActivityPub, Repo, User}
  alias RDF.{IRI, Turtle}
  import RDF.Sigils

  action_fallback CPub.Web.FallbackController

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, _params) do
    user = Repo.get!(User, conn.assigns[:id])

    conn
    |> put_view(RDFView)
    |> render(:show, data: user.profile)
  end

  @spec read_rdf_body(Plug.Conn.t()) ::
          {:ok, RDF.Graph.t() | RDF.Dataset.t(), Plug.Conn.t()} | {:error, any}
  defp read_rdf_body(conn) do
    with {:ok, body, conn} <- read_body(conn),
         {:ok, data} <- Turtle.Decoder.decode(body, base_iri: ~I<http://dummy-base-iri.fake/>) do
      {:ok, data |> RDF.Skolem.skolemize_graph(), conn}
    end
  end

  @spec post_to_outbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def post_to_outbox(conn, _params) do
    with user <- conn.assigns.user,
         {:ok, data, conn} <- read_rdf_body(conn),
         {:ok, %{activity: activity}} <- ActivityPub.handle_activity(data, user) do
      conn
      |> put_resp_header("Location", IRI.to_string(activity.id))
      |> send_resp(:created, "")
    end
  end

  @spec get_inbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_inbox(conn, _params) do
    user = conn.assigns.user

    if User.get_inbox_id(user) == conn.assigns.id do
      data = User.get_inbox(user)

      conn
      |> put_view(RDFView)
      |> render(:show, data: data)
    else
      unauthorized(conn)
    end
  end

  @spec get_outbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_outbox(conn, _params) do
    user = conn.assigns.user

    if User.get_outbox_id(user) == conn.assigns.id do
      data = User.get_outbox(user)

      conn
      |> put_view(RDFView)
      |> render(:show, data: data)
    else
      unauthorized(conn)
    end
  end
end
