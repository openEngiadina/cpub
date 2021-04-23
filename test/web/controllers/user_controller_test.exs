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

  alias RDF.JSON, as: RDFJSON
  alias RDF.Turtle, as: RDFTurtle

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

  describe "whoami/2" do
    test "returns user profile for authenticated request", %{conn: conn, user: user, token: token} do
      response =
        conn
        |> put_req_header("authorization", "Bearer " <> token.access_token)
        |> get(Routes.user_path(conn, :whoami))

      assert response.status == 200

      assert {:ok, _response_rdf} = Jason.decode(response.resp_body)

      {:ok, _profile} = user.profile |> CPub.ERIS.get_rdf()
    end

    test "returns 404 for unauthenticated request", %{conn: conn} do
      response = get(conn, Routes.user_path(conn, :whoami))

      assert response.status == 401
    end
  end

  describe "show/2" do
    test "returns user profile in response to application/ld+json", %{conn: conn, user: user} do
      # The URL used in testing seems to be `http://www.example.com/`
      _url =
        ("http://www.example.com" <>
           Routes.user_path(conn, :show, user.username))
        |> RDF.IRI.new!()

      response =
        conn
        |> put_req_header("accept", "application/ld+json")
        |> get(Routes.user_path(conn, :show, user.username))

      assert response.status == 200

      assert {:ok, _response_rdf} = Jason.decode(response.resp_body)

      {:ok, _profile} = user.profile |> CPub.ERIS.get_rdf()
    end

    test "returns user profile in response to application/activity+json",
         %{conn: conn, user: user} do
      # The URL used in testing seems to be `http://www.example.com/`
      _url =
        ("http://www.example.com" <>
           Routes.user_path(conn, :show, user.username))
        |> RDF.IRI.new!()

      response =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get(Routes.user_path(conn, :show, user.username))

      assert response.status == 200

      assert {:ok, _response_rdf} = Jason.decode(response.resp_body)

      {:ok, _profile} = user.profile |> CPub.ERIS.get_rdf()
    end

    test "returns user profile in response to application/rdf+json", %{conn: conn, user: user} do
      # The URL used in testing seems to be `http://www.example.com/`
      _url =
        ("http://www.example.com" <>
           Routes.user_path(conn, :show, user.username))
        |> RDF.IRI.new!()

      response =
        conn
        |> put_req_header("accept", "application/rdf+json")
        |> get(Routes.user_path(conn, :show, user.username))

      assert response.status == 200

      assert {:ok, _response_rdf} = RDFJSON.Decoder.decode(response.resp_body)

      {:ok, _profile} = user.profile |> CPub.ERIS.get_rdf()
    end

    test "returns user profile in response to text/turtle", %{conn: conn, user: user} do
      # The URL used in testing seems to be `http://www.example.com/`
      _url =
        ("http://www.example.com" <>
           Routes.user_path(conn, :show, user.username))
        |> RDF.IRI.new!()

      response =
        conn
        |> put_req_header("accept", "text/turtle")
        |> get(Routes.user_path(conn, :show, user.username))

      assert response.status == 200

      assert {:ok, _response_rdf} = RDFTurtle.Decoder.decode(response.resp_body)

      {:ok, _profile} = user.profile |> CPub.ERIS.get_rdf()
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
        RDF.Turtle.write_string!(graph)
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
