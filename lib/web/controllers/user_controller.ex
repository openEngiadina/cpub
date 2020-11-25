defmodule CPub.Web.UserController do
  use CPub.Web, :controller

  alias CPub.User
  alias RDF.FragmentGraph

  action_fallback CPub.Web.FallbackController

  # defp get_authorized_user(conn, scope: scope) do
  #   if scope_subset?(scope, conn.assigns.authorization.scope) do
  #     with authorization <- conn.assigns.authorization |> Repo.preload(:user) do
  #       {:ok, authorization.user}
  #     end
  #   else
  #     {:error, :unauthorized}
  #   end
  # end

  @doc """
  Show the `CPub.User`s profile.
  """
  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(%Plug.Conn{} = conn, %{"id" => username}) do
    with {:ok, user} <- User.get(username) do
      conn
      |> put_view(RDFView)
      |> render(:show,
        data:
          user
          |> User.get_profile()
          # Replace the base subject of the profile object with the request URL
          |> FragmentGraph.set_base_subject(request_url(conn))
      )
    end
  end

  # @spec post_to_outbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def post_to_outbox(%Plug.Conn{} = conn, %{graph: graph}) do
  #   with {:ok, user} <- get_authorized_user(conn, scope: [:write]),
  #        {:ok, %{activity: activity}} <- ActivityPub.handle_activity(graph, user) do
  #     conn
  #     |> put_resp_header(
  #       "location",
  #       Routes.object_url(conn, :show, %{"iri" => IRI.to_string(activity.activity_object_id)})
  #     )
  #     |> send_resp(:created, "")
  #   end
  # end

  # @spec get_inbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def get_inbox(%Plug.Conn{} = conn, %{"user_id" => username}) do
  #   with {:ok, user} <- get_authorized_user(conn, scope: [:write]) do
  #     if user.username == username do
  #       data = User.get_inbox(user)

  #       conn
  #       |> put_view(RDFView)
  #       |> render(:show, data: data)
  #     else
  #       {:error, :unauthorized}
  #     end
  #   end
  # end

  # @spec get_outbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def get_outbox(%Plug.Conn{} = conn, %{"user_id" => username}) do
  #   with {:ok, user} <- get_authorized_user(conn, scope: [:write]) do
  #     if user.username == username do
  #       data = User.get_outbox(user)

  #       conn
  #       |> put_view(RDFView)
  #       |> render(:show, data: data)
  #     else
  #       {:error, :unauthorized}
  #     end
  #   end
  # end
end
