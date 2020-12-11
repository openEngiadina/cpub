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
    test "post an ActivityStreams notes", %{conn: conn, user: user, token: token} do
      object =
        RDF.UUID.generate()
        |> RDF.type(AS.Note)
        |> AS.content("Hello")

      activity =
        RDF.UUID.generate()
        |> RDF.type(AS.Create)
        |> AS.object(object.subject)

      graph = RDF.Data.merge(activity, object)

      conn
      |> put_req_header("authorization", "Bearer " <> token.access_token)
      |> put_req_header("content-type", "text/turtle")
      |> post(
        Routes.user_outbox_path(conn, :post_to_outbox, user.username),
        graph
        |> RDF.Turtle.write_string!()
      )
    end
  end

  describe "get_inbox/2" do
    test "shows inbox", %{conn: conn, user: user, token: token} do
      conn
      |> put_req_header("authorization", "Bearer " <> token.access_token)
      |> get(Routes.user_inbox_path(conn, :get_inbox, user.username))
    end
  end

  describe "get_outbox/2" do
  end
end
