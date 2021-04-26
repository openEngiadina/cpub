# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.Authorization.TokenControllerTest do
  use ExUnit.Case
  use CPub.Web.ConnCase
  use CPub.DataCase

  alias CPub.User

  alias CPub.Web.Authorization
  alias CPub.Web.Authorization.{Client, Token}
  alias CPub.Web.UserController

  doctest CPub.Web.Authorization.TokenController

  setup do
    with {:ok, client} <-
           Client.create(%{
             "client_name" => "Test client",
             "scope" => "read write",
             "redirect_uris" => ["http://example.com/"]
           }),
         {:ok, user} <- User.create("alice"),
         {:ok, _registration} = User.Registration.create_internal(user, "123"),
         {:ok, authorization} <- Authorization.create(user, client, "read write") do
      {:ok, %{client: client, user: user, authorization: authorization}}
    end
  end

  describe "token/2 with :authorizaiton_code" do
    test "returns a valid token with client_id in authoriation header", %{
      conn: conn,
      authorization: authorization,
      user: user,
      client: client
    } do
      response =
        conn
        |> put_req_header(
          "authorization",
          "Basic " <> Base.encode64("#{client.id}:client_secret")
        )
        |> post(Routes.oauth_server_token_path(conn, :token), %{
          grant_type: "authorization_code",
          code: authorization.authorization_code,
          redirect_uri: "http://example.com/"
        })

      assert %{
               "access_token" => access_token,
               "expires_in" => expires_in,
               "refresh_token" => refresh_token,
               "me" => user_uri
             } = json_response(response, 200)

      assert {:ok, token} = Token.get(access_token)

      assert expires_in == Token.valid_for()
      assert access_token == token.access_token
      assert refresh_token == authorization.refresh_token
      assert user_uri == UserController.user_uri(conn, user)
    end

    test "returns a valid token with client_id in params", %{
      conn: conn,
      authorization: authorization,
      user: user,
      client: client
    } do
      response =
        conn
        |> post(Routes.oauth_server_token_path(conn, :token), %{
          grant_type: "authorization_code",
          code: authorization.authorization_code,
          client_id: client.id,
          redirect_uri: "http://example.com/"
        })

      assert %{
               "access_token" => access_token,
               "expires_in" => expires_in,
               "refresh_token" => refresh_token,
               "me" => user_uri
             } = json_response(response, 200)

      assert {:ok, token} = Token.get(access_token)

      assert expires_in == Token.valid_for()
      assert access_token == token.access_token
      assert refresh_token == authorization.refresh_token
      assert user_uri == UserController.user_uri(conn, user)
    end

    test "rejects a mismatch redirect uri", %{
      conn: conn,
      authorization: authorization,
      client: client
    } do
      response =
        conn
        |> post(Routes.oauth_server_token_path(conn, :token), %{
          grant_type: "authorization_code",
          code: authorization.authorization_code,
          client_id: client.id,
          redirect_uri: "http://example.org/"
        })

      assert %{"error" => "redirect_uri_masmatch", "error_description" => "redirect URI mismatch"} =
               json_response(response, 400)
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
          code: authorization.authorization_code,
          client_id: client.id,
          redirect_uri: "http://example.com/"
        })

      assert %{
               "access_token" => _access_token,
               "expires_in" => _expires_in,
               "refresh_token" => _refresh_token
             } = json_response(initial_response, 200)

      second_response =
        conn
        |> post(Routes.oauth_server_token_path(conn, :token), %{
          grant_type: "authorization_code",
          code: authorization.authorization_code,
          client_id: client.id
        })

      assert %{"error" => "code_used", "error_description" => "used code"} =
               json_response(second_response, 400)
    end
  end

  describe "token/2 with :refresh_token" do
    test "returns a fresh token", %{conn: conn, user: user, authorization: authorization} do
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
               "refresh_token" => refresh_token,
               "me" => user_uri
             } = json_response(response, 200)

      assert {:ok, token} = Token.get(access_token)
      assert expires_in == Token.valid_for()
      assert access_token == token.access_token
      assert refresh_token == authorization.refresh_token
      assert user_uri == UserController.user_uri(conn, user)
    end
  end

  describe "token/2 with :password flow" do
    test "returns a token", %{conn: conn, user: user} do
      response =
        conn
        |> post(Routes.oauth_server_token_path(conn, :token), %{
          grant_type: "password",
          username: user.username,
          password: "123"
        })

      assert %{
               "access_token" => access_token,
               "expires_in" => _expires_in,
               "refresh_token" => _refresh_token,
               "me" => user_uri
             } = json_response(response, 200)

      assert {:ok, _token} = Token.get(access_token)
      assert user_uri == UserController.user_uri(conn, user)
    end
  end
end
