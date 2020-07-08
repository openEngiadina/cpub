defmodule CPub.Web.ObjectControllerTest do
  @moduledoc false
  use ExUnit.Case
  use CPub.Web.ConnCase
  use CPub.RDFCase

  alias CPub.Object
  alias CPub.Repo

  doctest CPub.Web.ObjectController

  setup do
    id = RDF.UUID.generate()

    fg =
      FragmentGraph.new(id)
      |> FragmentGraph.add(RDF.type(), EX.Something)
      |> FragmentGraph.add(EX.content(), "Hellow")
      |> FragmentGraph.add_fragment_statement("abc", RDF.type(), EX.Subthing)
      |> FragmentGraph.add_fragment_statement("abc", EX.something(), 42)

    with {:ok, object} <- Object.new(fg) |> Object.create_changeset() |> Repo.insert() do
      {:ok, %{object: object}}
    end
  end

  describe "show/2" do
    test "responds with object as RDF/Turtle", %{conn: conn, object: object} do
      response =
        conn
        |> put_req_header("accept", "text/turtle")
        |> get(Routes.object_path(conn, :show, iri: object.id |> RDF.IRI.to_string()))

      assert response.status == 200
      assert {:ok, response_rdf} = RDF.Turtle.Decoder.decode(response.resp_body)

      assert object.content ==
               response_rdf
               |> RDF.FragmentGraph.new()
    end

    test "responds with object as RDF/JSON", %{conn: conn, object: object} do
      response =
        conn
        |> put_req_header("accept", "application/rdf+json")
        |> get(Routes.object_path(conn, :show, iri: object.id |> RDF.IRI.to_string()))

      assert response.status == 200
      assert {:ok, response_rdf} = RDF.JSON.Decoder.decode(response.resp_body)

      assert object.content ==
               response_rdf
               |> RDF.FragmentGraph.new()
    end

    test "responds with 404 if object does not exist", %{conn: conn} do
      uuid = UUID.uuid4()

      response =
        conn
        |> get(Routes.object_path(conn, :show, iri: "urn:uuid:" <> uuid))

      assert response.status == 404
    end

    # TODO what is the expected response 404 or 400?
    test "responds with 404 if invalid id", %{conn: conn} do
      uuid = "not-an-urn"

      response =
        conn
        |> get(Routes.object_path(conn, :show, iri: uuid))

      assert response.status == 404
    end
  end
end
