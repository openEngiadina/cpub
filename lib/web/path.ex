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

  @spec oauth_server_client_registration(Plug.Conn.t()) :: String.t()
  def oauth_server_client_registration(%Plug.Conn{} = conn) do
    conn |> Routes.oauth_server_client_path(:create) |> base_path()
  end

  @spec oauth_server_authorization(Plug.Conn.t()) :: String.t()
  def oauth_server_authorization(%Plug.Conn{} = conn) do
    conn |> Routes.oauth_server_authorization_path(:authorize) |> base_path()
  end

  @spec oauth_server_token(Plug.Conn.t()) :: String.t()
  def oauth_server_token(%Plug.Conn{} = conn) do
    conn |> Routes.oauth_server_token_path(:token) |> base_path()
  end

  @spec urn_resolution(Plug.Conn.t(), String.t(), String.t()) :: String.t()
  def urn_resolution(%Plug.Conn{} = conn, service, urn) do
    with path <- conn |> Routes.urn_resolution_path(:resolve, service) |> base_path() do
      "#{path}?#{urn}"
    end
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
