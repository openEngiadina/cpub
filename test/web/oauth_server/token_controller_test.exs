defmodule CPub.Web.OAuthServer.TokenControllerTest do
  use ExUnit.Case
  use CPub.Web.ConnCase

  alias CPub.User
  alias CPub.Repo
  alias CPub.Web.OAuthServer.Authorization
  alias CPub.Web.OAuthServer.Client
  alias CPub.Web.OAuthServer.Token

  doctest CPub.Web.OAuthServer.TokenController

  setup do
    with {:ok, client} <-
           Client.create(%{
             client_name: "Test client",
             redirect_uris: ["http://example.com/"],
             scopes: ["test"]
           }),
         {:ok, user} <- User.create(%{username: "alice", password: "123"}),
         {:ok, authorization} <-
           Authorization.create(%{
             client: client,
             user: user,
             scope: "test",
             redirect_uri: "http://example.com/"
           }) do
      {:ok, %{client: client, user: user, authorization: authorization}}
    end
  end

  describe "token/2 with :authorizaiton_code" do
    test "returns a valid token", %{
      conn: conn,
      authorization: authorization,
      client: client
    } do
      response =
        conn
        |> post(Routes.oauth_server_token_path(conn, :token), %{
          grant_type: "authorization_code",
          code: authorization.code,
          redirect_uri: authorization.redirect_uri,
          client_id: client.client_id
        })

      assert %{
               "access_token" => access_token,
               "expires_in" => expires_in,
               "refresh_token" => refresh_token
             } = json_response(response, 200)

      assert {:ok, token} = Repo.get_one_by(Token, %{access_token: access_token})

      assert expires_in == Token.valid_for()
      assert access_token == token.access_token
      assert refresh_token == authorization.refresh_token
    end

    test "rejects an already used access code", %{
      conn: conn,
      authorization: authorization,
      client: client
    } do
      initial_response =
        conn
        |> post(Routes.oauth_server_token_path(conn, :token), %{
          grant_type: "authorization_code",
          code: authorization.code,
          client_id: client.client_id
        })

      assert %{
               "access_token" => access_token,
               "expires_in" => expires_in,
               "refresh_token" => refresh_token
             } = json_response(initial_response, 200)

      second_response =
        conn
        |> post(Routes.oauth_server_token_path(conn, :token), %{
          grant_type: "authorization_code",
          code: authorization.code,
          client_id: client.client_id
        })

      assert %{"error" => "invalid_grant"} = json_response(second_response, 400)
    end
  end

  describe "token/2 with :refresh_token" do
    test "returns a fresh token", %{
      conn: conn,
      authorization: authorization
    } do
      # create an initial token
      assert {:ok, _initial_token} = Token.create(authorization)

      response =
        conn
        |> post(Routes.oauth_server_token_path(conn, :token), %{
          grant_type: "refresh_token",
          refresh_token: authorization.refresh_token
        })

      assert %{
               "access_token" => access_token,
               "expires_in" => expires_in,
               "refresh_token" => refresh_token
             } = json_response(response, 200)

      assert {:ok, token} = Repo.get_one_by(Token, %{access_token: access_token})

      assert expires_in == Token.valid_for()
      assert access_token == token.access_token
      assert refresh_token == authorization.refresh_token
    end
  end
end
