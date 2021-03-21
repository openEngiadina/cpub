# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.RegistrationController do
  @moduledoc """
  Implements interactive user registration.
  """

  use CPub.Web, :controller

  alias CPub.DB
  alias CPub.User

  alias CPub.Web.Authentication.RegistrationRequest
  alias CPub.Web.Authentication.SessionController

  alias Phoenix.Token

  action_fallback CPub.Web.FallbackController

  # External registration

  @doc """
  Register a new user with a registration_request (external registration).
  """
  @spec register(Plug.Conn.t(), map) :: Plug.Conn.t()
  def register(%Plug.Conn{method: "GET"} = conn, %{"request" => request_token}) do
    case get_request(conn, request_token) do
      {:ok, request} ->
        render_external_registration_form(conn, request: request, request_token: request_token)

      {:error, reason} ->
        reason = String.capitalize("#{reason}")

        conn
        |> put_flash(:error, "#{reason} request token.")
        |> render_external_registration_form(request: nil, request_token: request_token)
    end
  end

  def register(
        %Plug.Conn{method: "POST"} = conn,
        %{"request" => request_token, "username" => username}
      ) do
    case get_request(conn, request_token) do
      {:ok, request} ->
        with {:ok, user} <- User.create(username),
             {:ok, _registration} <-
               User.Registration.create_external(
                 user,
                 request.provider,
                 request.site,
                 request.external_id
               ) do
          SessionController.create_session(conn, user)
        else
          {:error, :user_already_exists} ->
            conn
            |> put_flash(:error, "Username is not available.")
            |> render_external_registration_form(request: request, request_token: request_token)

          _ ->
            conn
            |> put_flash(:error, "Registration failed.")
            |> render_external_registration_form(request: nil, request_token: request_token)
        end

      _ ->
        conn
        |> put_flash(:error, "Registration failed.")
        |> render_external_registration_form(request: nil, request_token: request_token)
    end
  end

  # Internal registration

  def register(%Plug.Conn{method: "GET"} = conn, _params) do
    render_internal_registration_form(conn, username: nil)
  end

  def register(
        %Plug.Conn{method: "POST"} = conn,
        %{"username" => username, "password" => password}
      ) do
    case create_user_with_internal_registration(username, password) do
      {:ok, user} ->
        SessionController.create_session(conn, user)

      _ ->
        conn
        |> put_flash(:error, "Registration failed.")
        |> render_internal_registration_form(username: username)
    end
  end

  # Helpers

  @spec get_request(Plug.Conn.t(), String.t()) ::
          {:ok, RegistrationRequest.t()} | {:error, any}
  defp get_request(conn, request_token) do
    with {:ok, request_id} <-
           Token.verify(conn, "registration_request", request_token, max_age: 86_400) do
      RegistrationRequest.get(request_id)
    end
  end

  @spec create_user_with_internal_registration(String.t(), String.t()) ::
          {:ok, User.t()} | {:error, any}
  defp create_user_with_internal_registration(username, password) do
    DB.transaction(fn ->
      with {:ok, user} <- User.create(username),
           {:ok, _registration} <- User.Registration.create_internal(user, password) do
        user
      end
    end)
  end

  # Render helpers

  @spec render_external_registration_form(Plug.Conn.t(), keyword) :: Plug.Conn.t()
  defp render_external_registration_form(conn, request: request, request_token: request_token) do
    path = Routes.authentication_registration_path(conn, :register, request: request_token)

    render(conn, "external_registration.html",
      callback_url: path,
      registration_external_id: request && request.external_id,
      username: request && request.username
    )
  end

  @spec render_internal_registration_form(Plug.Conn.t(), keyword) :: Plug.Conn.t()
  defp render_internal_registration_form(conn, username: username) do
    render(conn, "internal_registration.html",
      callback_url: Routes.authentication_registration_path(conn, :register),
      username: username
    )
  end
end
