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
  alias CPub.NS.Litepub, as: LP

  alias CPub.Web.Path

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

  @doc """
  GET from your inbox to read your latest messages (client-to-server)
  """
  @spec get_inbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_inbox(%Plug.Conn{} = conn, %{"user_id" => username} = params) do
    with {:ok, user} <- get_authorized_user(conn, scope: [:write]),
         {:ok, ^username} <- authorize_user(user, params),
         {:ok, inbox} <- User.Inbox.get(user) do
      conn
      |> put_view(RDFView)
      |> render(:show, data: as_container(inbox, RDF.iri(request_url(conn))))
    end
  end

  @doc """
  POST to your outbox to send messages to the world (client-to-server)
  """
  @spec post_to_outbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def post_to_outbox(%Plug.Conn{} = conn, %{"user_id" => username, graph: graph} = params) do
    with {:ok, user} <- get_authorized_user(conn, scope: [:write]),
         {:ok, ^username} <- authorize_user(user, params),
         {:ok, {activity_read_cap, _}} <- User.Outbox.post(user, graph) do
      conn
      |> put_resp_header("location", CPub.Magnet.from_eris_read_capability(activity_read_cap))
      |> send_resp(:created, "")
    else
      {:error, reason} when reason in [:not_supported, :not_found, :unauthorized] ->
        {:error, reason}

      {:error, _} ->
        {:error, :bad_request}
    end
  end

  @doc """
  GET from someone's outbox to see what messages they've posted (or at least the
  ones you're authorized to see) (client-to-server and/or server-to-server)
  """
  @spec get_outbox(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_outbox(%Plug.Conn{} = conn, %{"user_id" => username} = params) do
    with {:ok, user} <- get_authorized_user(conn, scope: [:write]),
         {:ok, ^username} <- authorize_user(user, params),
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
      |> RDF.Graph.add({id, RDF.type(), LDP.BasicContainer})
      |> RDF.Graph.add({id, RDF.type(), AS.Collection}),
      fn read_cap, graph ->
        iri =
          read_cap
          |> CPub.Magnet.from_eris_read_capability()
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

  @spec authorize_user(User.t(), map) :: {:ok, String.t()} | {:error, any}
  defp authorize_user(%User{username: username}, %{"user_id" => username}), do: {:ok, username}
  defp authorize_user(%User{}, _), do: {:error, :unauthorized}

  @spec render_user(Plug.Conn.t(), User.t()) :: Plug.Conn.t()
  defp render_user(%Plug.Conn{} = conn, %User{} = user) do
    conn
    |> put_view(RDFView)
    |> render(:show,
      data:
        user
        |> User.get_profile()
        # Replace the base subject of the profile object with the user's URI
        |> FragmentGraph.set_base_subject(Path.user(user))
        |> add_collections(user)
        |> add_endpoints()
    )
  end

  # Add collections properties to user profile generated with instance URL
  @spec add_collections(FragmentGraph.t(), User.t()) :: FragmentGraph.t()
  defp add_collections(%FragmentGraph{} = graph, %User{} = user) do
    user_inbox_iri = Path.user_inbox(user) |> RDF.iri()
    user_outbox_iri = Path.user_outbox(user) |> RDF.iri()
    user_followers_iri = Path.user_followers(user) |> RDF.iri()
    user_following_iri = Path.user_following(user) |> RDF.iri()

    graph
    |> FragmentGraph.add(LDP.inbox(), user_inbox_iri)
    |> FragmentGraph.add(AS.outbox(), user_outbox_iri)
    |> FragmentGraph.add(AS.followers(), user_followers_iri)
    |> FragmentGraph.add(AS.following(), user_following_iri)
  end

  # Add endpoints property to user profile generated with instance URL
  @spec add_endpoints(FragmentGraph.t()) :: FragmentGraph.t()
  defp add_endpoints(%FragmentGraph{} = graph) do
    oauth_server_authorization_iri = Path.oauth_server_authorization() |> RDF.iri()
    oauth_server_token_iri = Path.oauth_server_token() |> RDF.iri()

    oauth_server_client_registration_iri = Path.oauth_server_client_registration() |> RDF.iri()

    graph
    |> FragmentGraph.add_fragment_statement(
      "endpoints",
      AS.oauthAuthorizationEndpoint(),
      oauth_server_authorization_iri
    )
    |> FragmentGraph.add_fragment_statement(
      "endpoints",
      AS.oauthTokenEndpoint(),
      oauth_server_token_iri
    )
    |> FragmentGraph.add_fragment_statement(
      "endpoints",
      LP.oauthRegistrationEndpoint(),
      oauth_server_client_registration_iri
    )
  end
end
