# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.PublicController do
  use CPub.Web, :controller

  alias CPub.ActivityPub.Activity
  alias CPub.Public

  alias CPub.NS.ActivityStreams, as: AS

  action_fallback CPub.Web.FallbackController

  @spec get_public(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_public(%Plug.Conn{} = conn, _params) do
    data =
      Public.get_public()
      |> Activity.as_container(AS.Public)

    # |> Enum.map(&Activity.to_rdf/1)
    # |> Enum.reduce(Graph.new(), &Data.merge(&1, &2))

    conn
    |> put_view(RDFView)
    |> render(:show, data: data)
  end
end
