defmodule CPub.Web.UserControllerTest do
  @moduledoc false

  use ExUnit.Case
  use CPub.Web.ConnCase

  alias CPub.User

  alias RDF.FragmentGraph
  alias RDF.JSON, as: RDFJSON

  doctest CPub.Web.UserController

  setup do
    with {:ok, user} <- User.create(%{username: "alice", password: "123"}) do
      {:ok, %{user: user}}
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

      assert user.profile_object.content |> FragmentGraph.set_base_subject(url) ==
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

  describe "id/2" do
  end

  describe "verify/2" do
  end

  describe "post_to_outbox/2" do
  end

  describe "get_inbox/2" do
  end

  describe "get_outbox/2" do
  end
end
