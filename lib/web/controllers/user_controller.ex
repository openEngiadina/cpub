# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.UserController do
  use CPub.Web, :controller

  alias CPub.User
  alias RDF.FragmentGraph

  alias CPub.NS.ActivityStreams, as: AS
  alias CPub.NS.LDP

  action_fallback CPub.Web.FallbackController

  defp get_authorized_user(conn, scope: scope) do
    if scope_subset?(scope, conn.assigns.authorization.scope) do
      with {:ok, user} <- CPub.User.get_by_id(conn.assigns.authorization.user),
           true <- conn.params["user_id"] === user.username do
        {:ok, user}
      end
    else
      {:error, :unauthorized}
    end
  end

  # Add a inbox/outbox property to user profile based on current connection.
  defp add_inbox_outbox(profile, conn) do
    profile
    |> FragmentGraph.add(
      LDP.inbox(),
      Routes.user_inbox_url(conn, :get_inbox, conn.params["id"])
      |> RDF.iri()
    )
    |> FragmentGraph.add(
      AS.outbox(),
      Routes.user_outbox_url(conn, :get_outbox, conn.params["id"])
      |> RDF.iri()
    )
  end

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
          # Add the HTTP inbox/outbox
          |> add_inbox_outbox(conn)
          # Replace the base subject of the profile object with the request URL
          |> FragmentGraph.set_base_subject(request_url(conn))
      )
    end
  end

  @doc """
  Returns a RDF.Graph containing a list of objects in a ldp:Container and in an
  as:Collection.
  """
  def as_container(objects, id) do
    objects
    |> Enum.reduce(
      RDF.Graph.new()
      |> RDF.Graph.add({id, RDF.type(), RDF.iri(LDP.BasicContainer)})
      |> RDF.Graph.add({id, RDF.type(), RDF.iri(AS.Collection)}),
      fn read_cap, graph ->
        iri =
          ERIS.ReadCapability.to_string(read_cap)
          |> RDF.iri()

        graph
        |> RDF.Graph.add({id, LDP.member(), iri})
        |> RDF.Graph.add({id, AS.items(), iri})
      end
    )
  end

  @spec post_to_outbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def post_to_outbox(%Plug.Conn{} = conn, %{graph: graph}) do
    with {:ok, user} <- get_authorized_user(conn, scope: [:write]),
         {:ok, {activity_read_cap, _}} <- User.Outbox.post(user, graph) do
      conn
      |> put_resp_header(
        "location",
        ERIS.ReadCapability.to_string(activity_read_cap)
      )
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
    with {:ok, user} <- get_authorized_user(conn, scope: [:write]),
         # TODO: get real outbox
         {:ok, outbox} <- {:ok, MapSet.new()} do
      conn
      |> put_view(RDFView)
      |> render(:show, data: as_container(outbox, RDF.iri(request_url(conn))))
    end
  end
end
