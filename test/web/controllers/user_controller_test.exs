# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.UserControllerTest do
  @moduledoc false

  use ExUnit.Case
  use CPub.Web.ConnCase
  use CPub.DataCase

  alias CPub.User

  alias CPub.NS.ActivityStreams, as: AS

  alias RDF.FragmentGraph
  alias RDF.JSON, as: RDFJSON

  alias CPub.Web.Authorization
  alias CPub.Web.Authorization.Token

  doctest CPub.Web.UserController

  setup do
    with {:ok, user} <- User.create("alice"),
         {:ok, authorization} <- Authorization.create(user, [:read, :write]),
         {:ok, token} <- Token.create(authorization) do
      {:ok, %{user: user, token: token}}
    end
  end

  describe "show/2" do
    test "returns user profile", %{conn: conn, user: user} do
      # The URL used in testing seems to be `http://www.example.com/`
      url =
        ("http://www.example.com" <>
           Routes.user_path(conn, :show, user.username))
        |> RDF.IRI.new!()

      response =
        conn
        |> put_req_header("accept", "application/rdf+json")
        |> get(Routes.user_path(conn, :show, user.username))

      assert response.status == 200

      assert {:ok, response_rdf} = RDFJSON.Decoder.decode(response.resp_body)

      {:ok, profile} = user.profile |> CPub.ERIS.get_rdf()

      assert profile |> FragmentGraph.set_base_subject(url) ==
               response_rdf |> FragmentGraph.new()
    end

    test "returns 404 for unknown profile", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/rdf+json")
        |> get(Routes.user_path(conn, :show, "bob"))

      assert response.status == 404
    end
  end

  describe "post_to_outbox/2" do
    @tag :skip
    test "post an ActivityStreams notes", %{conn: conn, user: user, token: token} do
      object =
        FragmentGraph.new(RDF.UUID.generate())
        |> FragmentGraph.add(RDF.type(), AS.Note)
        |> FragmentGraph.add(AS.content(), "Hello")

      activity =
        FragmentGraph.new(RDF.UUID.generate())
        |> FragmentGraph.add(RDF.type(), AS.Create)
        |> FragmentGraph.add(AS.object(), object.base_subject)
        |> FragmentGraph.add(AS.object(), object.base_subject)

      graph = activity |> RDF.Data.merge(object)

      conn
      |> put_req_header("authorization", "Bearer " <> token.access_token)
      |> put_req_header("content-type", "text/turtle")
      |> post(
        Routes.user_outbox_path(conn, :post_to_outbox, user.id),
        graph
        |> RDF.Turtle.write_string!()
      )
    end
  end

  describe "get_inbox/2" do
    @tag :skip
    test "shows inbox", %{conn: conn, user: user, token: token} do
      conn
      |> put_req_header("authorization", "Bearer " <> token.access_token)
      |> get(Routes.user_inbox_path(conn, :get_inbox, user.id))
    end
  end

  describe "get_outbox/2" do
  end
end
