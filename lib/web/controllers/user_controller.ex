# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.UserController do
  use CPub.Web, :controller

  alias RDF.FragmentGraph

  alias CPub.User

  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP

  action_fallback CPub.Web.FallbackController

  @doc """
  Discover the `CPub.User`s profile from authenticated request.
  """
  @spec whoami(Plug.Conn.t(), map) :: Plug.Conn.t()
  def whoami(%Plug.Conn{} = conn, _params) do
    with {:ok, user} <- get_authorized_user(conn, scope: [:read]) do
      render_user(conn, user)
    end
  end

  @doc """
  Show the `CPub.User`s profile.
  """
  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(%Plug.Conn{} = conn, %{"id" => username}) do
    with {:ok, user} <- User.get(username) do
      render_user(conn, user)
    end
  end

  @spec post_to_outbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def post_to_outbox(%Plug.Conn{} = conn, %{graph: graph}) do
    with {:ok, user} <- get_authorized_user(conn, scope: [:write]),
         {:ok, {activity_read_cap, _}} <- User.Outbox.post(user, graph) do
      conn
      |> put_resp_header("location", ERIS.ReadCapability.to_string(activity_read_cap))
      |> send_resp(:created, "")
    end
  end

  @spec get_inbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_inbox(%Plug.Conn{} = conn, _params) do
    with {:ok, user} <- get_authorized_user(conn, scope: [:write]),
         {:ok, inbox} <- User.Inbox.get(user) do
      conn
      |> put_view(RDFView)
      |> render(:show, data: as_container(inbox, RDF.iri(request_url(conn))))
    end
  end

  @spec get_outbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_outbox(%Plug.Conn{} = conn, _params) do
    with {:ok, _user} <- get_authorized_user(conn, scope: [:write]),
         # TODO: get real outbox
         {:ok, outbox} <- {:ok, MapSet.new()} do
      conn
      |> put_view(RDFView)
      |> render(:show, data: as_container(outbox, RDF.iri(request_url(conn))))
    end
  end

  @doc """
  Returns a RDF.Graph containing a list of objects in a ldp:Container and in an
  as:Collection.
  """
  @spec as_container(MapSet.t(), RDF.IRI.t()) :: RDF.Graph.t()
  def as_container(objects, id) do
    Enum.reduce(
      objects,
      RDF.Graph.new()
      |> RDF.Graph.add({id, RDF.type(), RDF.iri(LDP.BasicContainer)})
      |> RDF.Graph.add({id, RDF.type(), RDF.iri(AS.Collection)}),
      fn read_cap, graph ->
        iri =
          read_cap
          |> ERIS.ReadCapability.to_string()
          |> RDF.iri()

        graph
        |> RDF.Graph.add({id, LDP.member(), iri})
        |> RDF.Graph.add({id, AS.items(), iri})
      end
    )
  end

  @spec get_authorized_user(Plug.Conn.t(), keyword) :: {:ok, User.t()} | {:error, any}
  defp get_authorized_user(
         %Plug.Conn{assigns: %{authorization: authorization}},
         scope: scope
       ) do
    with true <- scope_subset?(scope, authorization.scope),
         {:ok, user} <- User.get_by_id(authorization.user) do
      {:ok, user}
    else
      _ ->
        {:error, :unauthorized}
    end
  end

  defp get_authorized_user(%Plug.Conn{} = _, _), do: {:error, :unauthorized}

  # Add a inbox/outbox property to user profile based on current connection.
  @spec add_inbox_outbox(User.t(), Plug.Conn.t()) :: FragmentGraph.t()
  defp add_inbox_outbox(user, conn) do
    user_inbox_iri = Routes.user_inbox_url(conn, :get_inbox, user.username) |> RDF.iri()
    user_outbox_iri = Routes.user_outbox_url(conn, :get_outbox, user.username) |> RDF.iri()

    user
    |> User.get_profile()
    |> FragmentGraph.add(LDP.inbox(), user_inbox_iri)
    |> FragmentGraph.add(AS.outbox(), user_outbox_iri)
  end

  @spec render_user(Plug.Conn.t(), User.t()) :: Plug.Conn.t()
  defp render_user(%Plug.Conn{} = conn, %User{} = user) do
    conn
    |> put_view(RDFView)
    |> render(:show,
      data:
        user
        # Add the HTTP inbox/outbox
        |> add_inbox_outbox(conn)
        # Replace the base subject of the profile object with the request URL
        |> FragmentGraph.set_base_subject(request_url(conn))
    )
  end
end
