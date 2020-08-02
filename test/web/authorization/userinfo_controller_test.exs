defmodule CPub.Web.Authorization.UserInfoControllerTest do
  use ExUnit.Case
  use CPub.Web.ConnCase

  alias CPub.User

  alias CPub.Web.Authorization
  alias CPub.Web.Authorization.Token

  setup do
    with {:ok, user} <- User.create(%{username: "alice", password: "123"}),
         {:ok, authorization} <-
           Authorization.create(%{
             user_id: user.id,
             scope: [:openid]
           }),
         {:ok, token} <- Token.create(authorization) do
      {:ok, %{user: user, token: token}}
    end
  end

  describe "userinfo/2" do
    test "returns user info", %{conn: conn, token: token, user: user} do
      response =
        conn
        |> put_req_header("authorization", "Bearer " <> token.access_token)
        |> get(Routes.oauth_server_user_info_path(conn, :userinfo))

      body = json_response(response, 200)

      assert body["sub"] == User.actor_url(user) |> RDF.IRI.to_string()
    end

    test "returns error when no token is given", %{conn: conn} do
      response =
        conn
        |> get(Routes.oauth_server_user_info_path(conn, :userinfo))

      body = json_response(response, 400)

      assert body["error"] == "invalid_request"
    end

    test "returns error when :openid scope is not granted", %{conn: conn, user: user} do
      with {:ok, authorization} <-
             Authorization.create(%{
               user_id: user.id,
               scope: [:read]
             }),
           {:ok, token} <- Token.create(authorization) do
        response =
          conn
          |> put_req_header("authorization", "Bearer " <> token.access_token)
          |> get(Routes.oauth_server_user_info_path(conn, :userinfo))

        body = json_response(response, 400)

        assert body["error"] == "invalid_request"
      end
    end
  end
end
