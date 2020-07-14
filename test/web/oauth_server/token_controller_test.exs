defmodule CPub.Web.OAuthServer.TokenControllerTest do
  use ExUnit.Case
  use CPub.Web.ConnCase

  alias CPub.User
  alias CPub.Repo
  alias CPub.Web.Authentication.Session
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

  describe "token/2" do
    test "redirect to redirect_uri with valid token", %{
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
  end
end
