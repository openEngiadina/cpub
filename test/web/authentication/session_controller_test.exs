defmodule CPub.Web.Authentication.SessionControllerTest do
  use ExUnit.Case
  use CPub.Web.ConnCase

  alias CPub.User
  alias CPub.Repo
  alias CPub.Web.Authentication

  doctest CPub.Web.Authentication.SessionController

  setup do
    with {:ok, user} = User.create(%{username: "alice", password: "123"}) do
      {:ok, %{user: user}}
    end
  end

  describe "login/2" do
    test "renders login screen when not authenticated", %{conn: conn} do
      response =
        conn
        |> get(Routes.authentication_session_path(conn, :login))

      assert html_response(response, 200) =~ "Login"
    end

    test "redirectes to local provider for local user", %{
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
               Routes.authentication_provider_path(conn, :request, "local", %{
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
