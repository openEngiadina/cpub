# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.NodeInfo.NodeInfoController do
  @moduledoc """
  Implements the NodeInfo endpoint
  (https://github.com/jhass/nodeinfo/blob/main/PROTOCOL.md).
  """

  use CPub.Web, :controller

  alias CPub.Config

  alias CPub.Web.NodeInfo

  @profile "http://nodeinfo.diaspora.software/ns/schema/"

  @spec schemas(Plug.Conn.t(), map) :: Plug.Conn.t()
  def schemas(%Plug.Conn{} = conn, _params) do
    response = %{
      links: [
        %{
          rel: "#{@profile}2.0",
          href: "#{Config.base_url()}nodeinfo/2.0"
        },
        %{
          rel: "#{@profile}2.1",
          href: "#{Config.base_url()}nodeinfo/2.1"
        }
      ]
    }

    json(conn, response)
  end

  @spec node_info(Plug.Conn.t(), map) :: Plug.Conn.t()
  @dialyzer {:nowarn_function, node_info: 2}
  def node_info(%Plug.Conn{} = conn, %{"version" => version}) do
    case NodeInfo.get_node_info(version) do
      node_info when is_map(node_info) ->
        conn
        |> put_resp_header("content-type", "application/json; profile=#{@profile}#{version}#")
        |> json(node_info)

      :error ->
        conn
        |> put_status(404)
        |> json("NodeInfo schema version #{version} is not handled")
    end
  end
end
