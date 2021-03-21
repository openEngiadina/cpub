# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.ResolveController do
  use CPub.Web, :controller

  alias CPub.ERIS

  action_fallback CPub.Web.FallbackController

  @spec get(any) :: {:ok, any} | {:error, any}
  def get("urn:erisx2:" <> _ = urn), do: ERIS.get_rdf(urn)
  def get(nil), do: {:error, :bad_request}
  def get(_), do: {:error, :not_found}

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(%Plug.Conn{} = conn, _) do
    with {:ok, object} <- get(conn.query_params["iri"]) do
      conn
      |> put_view(RDFView)
      |> render(:show, data: object)
    end
  end
end
