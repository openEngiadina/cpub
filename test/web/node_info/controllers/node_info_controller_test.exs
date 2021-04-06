# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.NodeInfo.NodeInfoControllerTest do
  @moduledoc false

  use ExUnit.Case
  use CPub.Web.ConnCase

  doctest CPub.Web.NodeInfo.NodeInfoController

  describe "schemas/2" do
    test "returns available schemas with valid links", %{conn: conn} do
      links =
        conn
        |> put_req_header("accept", "application/json")
        |> get(Routes.node_info_path(conn, :schemas, %{}))
        |> json_response(200)
        |> Map.fetch!("links")

      Enum.each(links, fn link ->
        href = Map.fetch!(link, "href")

        schema =
          conn
          |> get(href)
          |> json_response(200)

        assert %{
                 "version" => _,
                 "software" => _,
                 "protocols" => _,
                 "services" => _,
                 "openRegistrations" => _,
                 "usage" => _,
                 "metadata" => _
               } = schema
      end)
    end
  end

  describe "node_info/2" do
    test "returns software.repository field in nodeinfo 2.1", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get(Routes.node_info_path(conn, :node_info, "2.1"))
        |> json_response(200)

      assert CPub.Application.repository() == response["software"]["repository"]
    end
  end
end
