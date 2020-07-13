defmodule CPub.Web.OAuthServer.AuthorizationControllerTest do
  use ExUnit.Case
  use CPub.Web.ConnCase

  alias CPub.User
  alias CPub.Web.Authentication.Session
  alias CPub.Web.OAuthServer.Authorization
  alias CPub.Web.OAuthServer.Client

  setup do
    with {:ok, client} =
           Client.create(%{
             client_name: "Test client",
             redirect_uris: ["http://example.com/"],
             scopes: ["test"]
           }) do
      {:ok, %{client: client}}
    end
  end

  setup do
    with {:ok, user} <- User.create(%{username: "alice", password: "123"}),
         {:ok, session} <- Session.create(user) do
      {:ok, %{user: user, session: session}}
    end
  end

  describe "authorize/2" do
    test "redirects to login if not authenticated", %{conn: conn, client: client} do
      authorization_params = %{
        "client_id" => client.client_id,
        "response_type" => "code",
        "state" => 42
      }

      response =
        conn
        |> get(Routes.oauth_server_authorization_path(conn, :authorize, authorization_params))

      assert redirected_to(response) ==
               Routes.authentication__path(conn, :login,
                 on_success:
                   Routes.oauth_server_authorization_path(conn, :authorize, authorization_params)
               )
    end

    test "display authorization request when authenticated", %{
      conn: conn,
      client: client,
      session: session
    } do
      authorization_params = %{
        "client_id" => client.client_id,
        "response_type" => "code",
        "state" => 42
      }

      response =
        conn
        |> put_session(:session_id, session.id)
        |> get(Routes.oauth_server_authorization_path(conn, :authorize, authorization_params))

      assert html_response(response, 200) =~ "OAuth 2.0 Authorization"
    end

    test "return error when redirec_uri is invalid", %{conn: conn, client: client} do
      authorization_params = %{
        "client_id" => client.client_id,
        "response_type" => "code",
        "state" => 42,
        "redirect_uri" => "http://example.com/wrong"
      }

      response =
        conn
        |> get(Routes.oauth_server_authorization_path(conn, :authorize, authorization_params))

      assert text_response(response, 400) =~
               "redirect_uri not valid or not allowed for client."
    end

    test "redirect with a valid authroization code on accept", %{
      conn: conn,
      client: client,
      session: session
    } do
      authorization_params = %{
        "client_id" => client.client_id,
        "response_type" => "code",
        "state" => 42
      }

      response =
        conn
        |> put_session(:session_id, session.id)
        |> post(Routes.oauth_server_authorization_path(conn, :authorize, authorization_params), %{
          "request_accepted" => %{}
        })

      assert redirect_uri =
               response
               |> redirected_to()
               |> URI.parse()

      code = redirect_uri.query |> URI.decode_query() |> Access.get("code")

      assert {:ok, code} = CPub.Repo.get_one_by(Authorization, %{code: code})
    end

    test "redirect with error on deny", %{
      conn: conn,
      client: client,
      session: session
    } do
      authorization_params = %{
        "client_id" => client.client_id,
        "response_type" => "code",
        "state" => 42
      }

      response =
        conn
        |> put_session(:session_id, session.id)
        |> post(Routes.oauth_server_authorization_path(conn, :authorize, authorization_params), %{
          "request_denied" => %{}
        })

      assert redirect_uri =
               response
               |> redirected_to() =~ "http://example.com/"
    end
  end
end
