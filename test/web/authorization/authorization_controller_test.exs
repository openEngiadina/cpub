defmodule CPub.Web.Authorization.AuthorizationControllerTest do
  use ExUnit.Case
  use CPub.DataCase
  use CPub.Web.ConnCase

  alias CPub.User

  alias CPub.Web.Authentication
  alias CPub.Web.Authorization

  doctest CPub.Web.Authorization.AuthorizationController

  setup do
    case Authorization.Client.create(%{
           "client_name" => "Test client",
           "scope" => "read write",
           "redirect_uris" => ["http://example.com/"]
         }) do
      {:ok, client} ->
        {:ok, %{client: client}}
    end
  end

  setup do
    with {:ok, user} <- User.create("alice"),
         {:ok, session} <- Authentication.Session.create(user) do
      {:ok, %{user: user, session: session}}
    end
  end

  describe "authorize/2 with :code flow (authorization code)" do
    test "redirects to login if not authenticated", %{conn: conn, client: client} do
      authorization_params = %{
        "client_id" => client.id,
        "response_type" => "code",
        "state" => 42
      }

      response =
        conn
        |> get(Routes.oauth_server_authorization_path(conn, :authorize, authorization_params))

      assert redirected_to(response) ==
               Routes.authentication_session_path(conn, :login,
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
        "client_id" => client.id,
        "response_type" => "code",
        "state" => 42
      }

      response =
        conn
        |> put_session(:session_id, session.id)
        |> get(Routes.oauth_server_authorization_path(conn, :authorize, authorization_params))

      assert html_response(response, 200) =~ "OAuth 2.0 Authorization"
    end

    test "return error when redirect_uri is invalid", %{conn: conn, client: client} do
      authorization_params = %{
        "client_id" => client.id,
        "response_type" => "code",
        "state" => 42,
        "redirect_uri" => "http://example.com/wrong"
      }

      response =
        conn
        |> get(Routes.oauth_server_authorization_path(conn, :authorize, authorization_params))

      assert %{
               "error" => "invalid_request",
               "error_description" => "redirect_uri not valid or not allowed for client."
             } = json_response(response, 400)
    end

    test "redirect with a valid authorization code on accept", %{
      conn: conn,
      client: client,
      session: session
    } do
      authorization_params = %{
        "client_id" => client.id,
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

      assert {:ok, authoriation} = Authorization.get_by_code(code)
    end

    test "redirect with error on deny", %{
      conn: conn,
      client: client,
      session: session
    } do
      authorization_params = %{
        "client_id" => client.id,
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
