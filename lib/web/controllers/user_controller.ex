defmodule CPub.Web.UserController do
  use CPub.Web, :controller

  alias CPub.{ActivityPub, Repo, User}
  alias RDF.{FragmentGraph, Graph, IRI}

  action_fallback CPub.Web.FallbackController

  @doc """
  Show the `CPub.User`s profile.
  """
  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(%Plug.Conn{} = conn, %{"id" => username}) do
    with {:ok, user} <- Repo.get_one_by(User, %{username: username}),
         user <- user |> Repo.preload(:profile_object) do
      conn
      |> put_view(RDFView)
      |> render(:show,
        data:
          user.profile_object.content
          # Replace the UUID of the profile object with the request URL
          |> FragmentGraph.set_base_subject(request_url(conn))
      )
    end
  end

  @spec id(Plug.Conn.t(), map) :: Plug.Conn.t()
  def id(%Plug.Conn{assigns: %{user: %User{id: user_id} = user}} = conn, _params) do
    profile = Graph.set_base_iri(user.profile, IRI.new!("#{user_id}/"))

    conn
    |> put_view(RDFView)
    |> render(:show, data: profile)
  end

  @spec verify(Plug.Conn.t(), map) :: Plug.Conn.t()
  def verify(%Plug.Conn{assigns: %{user: %User{username: username}}} = conn, _params) do
    json(conn, %{username: username})
  end

  @spec post_to_outbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def post_to_outbox(%Plug.Conn{} = conn, %{graph: graph}) do
    with user <- conn.assigns.user,
         {:ok, %{activity: activity}} <- ActivityPub.handle_activity(graph, user) do
      conn
      |> put_resp_header("Location", IRI.to_string(activity.id))
      |> send_resp(:created, "")
    end
  end

  @spec get_inbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_inbox(%Plug.Conn{assigns: %{id: user_id, user: %User{} = user}} = conn, _params) do
    if User.get_inbox_id(user) == user_id do
      data = User.get_inbox(user)

      conn
      |> put_view(RDFView)
      |> render(:show, data: data)
    else
      unauthorized(conn)
    end
  end

  @spec get_outbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_outbox(%Plug.Conn{assigns: %{id: user_id, user: %User{} = user}} = conn, _params) do
    if User.get_outbox_id(user) == user_id do
      data = User.get_outbox(user)

      conn
      |> put_view(RDFView)
      |> render(:show, data: data)
    else
      unauthorized(conn)
    end
  end
end
