# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.ResolveControllerTest do
  @moduledoc false
  use ExUnit.Case
  use CPub.Web.ConnCase
  use CPub.RDFCase

  doctest CPub.Web.ResolveController

  setup do
    fg =
      FragmentGraph.new()
      |> FragmentGraph.add(RDF.type(), EX.Something)
      |> FragmentGraph.add(EX.content(), "Hellow")
      |> FragmentGraph.add_fragment_statement("abc", RDF.type(), EX.Subthing)
      |> FragmentGraph.add_fragment_statement("abc", EX.something(), 42)
      |> FragmentGraph.finalize()

    with {:ok, read_capability} <- fg |> CPub.ERIS.put() do
      {:ok, %{fg: fg, read_capability: read_capability}}
    end
  end

  describe "show/2" do
    test "responds with ERIS encoded Fragment Graph as RDF/Turtle", %{
      conn: conn,
      fg: fg,
      read_capability: read_capability
    } do
      response =
        conn
        |> put_req_header("accept", "text/turtle")
        |> get(
          Routes.resolve_path(conn, :show, iri: read_capability |> ERIS.ReadCapability.to_string())
        )

      assert response.status == 200
      assert {:ok, response_rdf} = RDF.Turtle.Decoder.decode(response.resp_body)

      assert fg ==
               response_rdf
               |> RDF.FragmentGraph.new()
    end

    test "responds with ERIS encoded Fragment Graph as RDF/JSON", %{
      conn: conn,
      fg: fg,
      read_capability: read_capability
    } do
      response =
        conn
        |> put_req_header("accept", "application/rdf+json")
        |> get(
          Routes.resolve_path(conn, :show, iri: read_capability |> ERIS.ReadCapability.to_string())
        )

      assert response.status == 200
      assert {:ok, response_rdf} = RDF.JSON.Decoder.decode(response.resp_body)

      assert fg ==
               response_rdf
               |> RDF.FragmentGraph.new()
    end

    test "responds with 404 if object does not exist", %{conn: conn} do
      uuid = UUID.uuid4()

      response =
        conn
        |> get(Routes.resolve_path(conn, :show, iri: "urn:uuid:" <> uuid))

      assert response.status == 404
    end

    # TODO what is the expected response 404 or 400?
    test "responds with 404 if invalid id", %{conn: conn} do
      uuid = "not-an-urn"

      response =
        conn
        |> get(Routes.resolve_path(conn, :show, iri: uuid))

      assert response.status == 404
    end
  end
end
