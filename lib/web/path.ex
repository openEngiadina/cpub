# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Path do
  @moduledoc """
  Most used routes paths generated with real instance URL.
  """

  use CPub.Web, :controller

  alias CPub.Config
  alias CPub.User

  @spec authentication_session_login(Plug.Conn.t(), Keyword.t() | map) :: String.t()
  def authentication_session_login(%Plug.Conn{} = conn, params \\ []) do
    conn |> Routes.authentication_session_path(:login, params) |> base_path()
  end

  @spec user(Plug.Conn.t(), User.t()) :: String.t()
  def user(%Plug.Conn{} = conn, %User{username: username}) do
    conn |> Routes.user_path(:show, username) |> base_path()
  end

  @spec user_inbox(Plug.Conn.t(), User.t()) :: String.t()
  def user_inbox(%Plug.Conn{} = conn, %User{username: username}) do
    conn |> Routes.user_inbox_path(:get_inbox, username) |> base_path()
  end

  @spec user_outbox(Plug.Conn.t(), User.t()) :: String.t()
  def user_outbox(%Plug.Conn{} = conn, %User{username: username}) do
    conn |> Routes.user_outbox_path(:get_outbox, username) |> base_path()
  end

  @spec base_path(String.t()) :: String.t()
  def base_path(path) do
    Config.base_url()
    |> URI.parse()
    |> URI.merge(path)
    |> to_string
  end
end
