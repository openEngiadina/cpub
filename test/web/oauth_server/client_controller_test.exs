defmodule CPub.Web.OAuthServer.ClientControllerTest do
  use ExUnit.Case
  use CPub.Web.ConnCase

  alias CPub.Web.OAuthServer.Client

  doctest CPub.Web.OAuthServer.ClientController

  describe "create/2" do
    test "creates a new client", %{conn: conn} do
      response =
        conn
        |> post(Routes.oauth_client_path(conn, :create), %{client_name: "Test Client"})

      assert %{"client_name" => "Test Client"} =
               response
               |> json_response(201)
    end
  end

  describe "show/2" do
    test "responds with the client", %{conn: conn} do
      assert {:ok, client} = Client.create(%{client_name: "Test Client"})

      response =
        conn
        |> get(Routes.oauth_client_path(conn, :show, client.id))

      assert client_response =
               response
               |> json_response(200)

      assert client_response["client_name"] == client.client_name
      assert client_response["client_id"] == client.client_id
      assert client_response["client_secret"] == client.client_secret
      assert client_response["redirect_uris"] == client.redirect_uris
    end
  end
end
