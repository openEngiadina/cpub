# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authentication.SessionControllerTest do
  use ExUnit.Case
  use CPub.Web.ConnCase
  use CPub.DataCase

  alias CPub.User

  alias CPub.Web.Authentication

  doctest CPub.Web.Authentication.SessionController

  setup do
    with {:ok, user} <- User.create("alice"),
         {:ok, _registration} <- User.Registration.create_internal(user, "123") do
      {:ok, %{user: user}}
    end
  end

  describe "login/2" do
    # TODO fix this test
    # test "renders login screen when not authenticated", %{conn: conn} do
    #   response =
    #     conn
    #     |> get(Routes.authentication_session_path(conn, :login))

    #   assert html_response(response, 200) =~ "Login"
    # end

    test "redirectes to internal provider for user with internal registration", %{
      conn: conn,
      user: user
    } do
      response =
        conn
        |> post(
          Routes.authentication_session_path(conn, :login),
          %{
            "credential" => user.username
          }
        )

      assert redirected_to(response) ==
               Routes.authentication_provider_path(conn, :request, "internal", %{
                 username: user.username
               })
    end

    test "redirects when already authenticated", %{conn: conn, user: user} do
      {:ok, session} = Authentication.Session.create(user)

      response =
        conn
        |> put_session(:session_id, session.id)
        |> get(Routes.authentication_session_path(conn, :login), %{"on_success" => "/success"})

      assert redirected_to(response) == "/success"
    end
  end
end
