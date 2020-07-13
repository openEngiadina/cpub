defmodule CPub.Web.Authentication.AuthenticationControllerTest do
  use ExUnit.Case
  use CPub.Web.ConnCase

  alias CPub.User
  alias CPub.Repo
  alias CPub.Web.Authentication

  setup do
    with {:ok, user} = User.create(%{username: "alice", password: "123"}) do
      {:ok, %{user: user}}
    end
  end

  describe "login/2" do
    test "renders login screen when not authenticated", %{conn: conn} do
      response =
        conn
        |> get(Routes.authentication__path(conn, :login))

      assert html_response(response, 200) =~ "CPub Login"
    end

    test "creates new session and redirects when authentication succeeds", %{
      conn: conn,
      user: user
    } do
      response =
        conn
        |> post(Routes.authentication__path(conn, :login), %{
          "login_form" => %{
            "username" => user.username,
            "password" => "123",
            "on_success" => "/success"
          }
        })

      assert redirected_to(response) == "/success"

      session_id = response |> fetch_session |> get_session(:session_id)

      assert {:ok, session} = CPub.Repo.get_one(Authentication.Session, session_id)

      assert session.user_id == user.id
    end

    test "fails on invalid credentials", %{conn: conn, user: user} do
      response =
        conn
        |> post(Routes.authentication__path(conn, :login), %{
          "login_form" => %{
            "username" => user.username,
            "password" => "1234",
            "on_success" => "/success"
          }
        })

      assert html_response(response, :unauthorized) =~ "CPub Login"
    end

    test "redirects when already authenticated", %{conn: conn, user: user} do
      {:ok, session} = Authentication.Session.create(user)

      response =
        conn
        |> put_session(:session_id, session.id)
        |> get(Routes.authentication__path(conn, :login), %{"on_success" => "/success"})

      assert redirected_to(response) == "/success"
    end
  end
end
