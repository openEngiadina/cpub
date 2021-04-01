# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.WebFinger.WebFingerController do
  @moduledoc """
  Implements the WebFinger endpoint (https://tools.ietf.org/html/rfc7033).
  """

  use CPub.Web, :controller

  alias CPub.Web.WebFinger

  @spec resource(Plug.Conn.t(), map) :: Plug.Conn.t()
  def resource(%Plug.Conn{} = conn, %{"resource" => "acct:" <> account = resource} = params) do
    case WebFinger.account(account, params) do
      {:ok, response} ->
        json(conn, response)

      {:error, _reason} ->
        conn
        |> put_status(404)
        |> json("Resource #{resource} is not found")
    end
  end

  def resource(%Plug.Conn{} = conn, _params), do: send_resp(conn, 400, "Bad Request")
end
