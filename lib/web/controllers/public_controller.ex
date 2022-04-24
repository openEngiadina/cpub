# SPDX-FileCopyrightText: 2020-2022 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.PublicController do
  use CPub.Web, :controller

  alias CPub.Public

  alias CPub.NS.ActivityStreams, as: AS

  require Logger

  action_fallback CPub.Web.FallbackController

  @spec get_public(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_public(%Plug.Conn{} = conn, _params) do
    with {:ok, public} = Public.get() do
      conn
      |> put_view(RDFView)
      |> render(:show, data: CPub.Web.UserController.as_container(public, RDF.iri(AS.Public)))
    end
  end
end
