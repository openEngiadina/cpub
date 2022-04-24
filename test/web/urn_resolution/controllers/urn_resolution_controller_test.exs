# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.URNResolution.URNResolutionControllerTest do
  @moduledoc false
  use ExUnit.Case
  use CPub.Web.ConnCase
  use CPub.RDFCase

  doctest CPub.Web.URNResolution.URNResolutionController

  setup do
    fg =
      FragmentGraph.new()
      |> FragmentGraph.add({RDF.type(), EX.Something})
      |> FragmentGraph.add({EX.content(), "Hellow"})
      |> FragmentGraph.add_fragment_statement("abc", {RDF.type(), EX.Subthing})
      |> FragmentGraph.add_fragment_statement("abc", {EX.something(), 42})
      |> FragmentGraph.finalize()

    with {:ok, read_capability} <- fg |> CPub.ERIS.put() do
      {:ok, %{fg: fg, read_capability: read_capability}}
    end
  end

  describe "resolve/2 for N2R servive" do
    test "responds with ERIS encoded Fragment Graph as RDF/Turtle",
         %{conn: conn, fg: fg, read_capability: read_capability} do
      response =
        conn
        |> put_req_header("accept", "text/turtle")
        |> get(
          Routes.urn_resolution_path(conn, :resolve, "N2R", %{
            ERIS.ReadCapability.to_string(read_capability) => ""
          })
        )

      assert response.status == 200
      assert {:ok, response_rdf} = RDF.Turtle.Decoder.decode(response.resp_body)

      assert fg == RDF.FragmentGraph.new(response_rdf)
    end

    test "responds with ERIS encoded Fragment Graph as RDF/JSON",
         %{conn: conn, fg: fg, read_capability: read_capability} do
      response =
        conn
        |> put_req_header("accept", "application/rdf+json")
        |> get(
          Routes.urn_resolution_path(conn, :resolve, "N2R", %{
            ERIS.ReadCapability.to_string(read_capability) => ""
          })
        )

      assert response.status == 200
      assert {:ok, response_rdf} = RDF.JSON.Decoder.decode(response.resp_body)

      assert fg == RDF.FragmentGraph.new(response_rdf)
    end

    test "responds with 404 if object does not exist", %{conn: conn} do
      uuid = UUID.uuid4()

      response =
        conn
        |> get(Routes.urn_resolution_path(conn, :resolve, "N2R", %{"urn:uuid:#{uuid}" => ""}))

      assert response.status == 404
    end

    test "responds with 404 if invalid id", %{conn: conn} do
      uuid = "not-an-urn"

      response =
        conn
        |> get(Routes.urn_resolution_path(conn, :resolve, "N2R", %{uuid => ""}))

      assert response.status == 400
    end
  end

  test "responds with 404 for unknown service", %{conn: conn} do
    response =
      conn
      |> get(Routes.urn_resolution_path(conn, :resolve, "UNK", %{}))

    assert response.status == 400
  end
end
