# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.SessionPlug do
  @moduledoc """
  Plug that fetches and assigns `CPub.Web.Authentication.Session` from `Plug.Session`.
  """

  import Plug.Conn

  alias CPub.Web.Authentication.Session

  def init(opts), do: opts

  def call(%Plug.Conn{} = conn, _opts) do
    session_id =
      conn
      |> fetch_session()
      |> get_session(:session_id)

    if is_nil(session_id) do
      conn
    else
      case Session.get_by_id(session_id) do
        {:ok, session} ->
          conn
          |> assign(:session, session)

        _ ->
          conn
          |> delete_session(:session_id)
      end
    end
  end
end
