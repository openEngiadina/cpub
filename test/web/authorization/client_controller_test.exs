defmodule CPub.Web.Authorization.ClientControllerTest do
  use ExUnit.Case
  use CPub.Web.ConnCase

  alias CPub.Web.Authorization.Client

  doctest CPub.Web.Authorization.ClientController

  describe "create/2" do
    test "creates a new client", %{conn: conn} do
      response =
        conn
        |> post(Routes.oauth_server_client_path(conn, :create), %{
          client_name: "Test Client",
          redirect_uris: ["http://example.com/"],
          scopes: ["test"]
        })

      assert %{
               "client_name" => "Test Client",
               "redirect_uris" => ["http://example.com/"],
               "scopes" => ["test"]
             } =
               response
               |> json_response(201)
    end
  end

  describe "show/2" do
    test "responds with the client", %{conn: conn} do
      assert {:ok, client} =
               Client.create(%{
                 client_name: "Test Client",
                 redirect_uris: ["http://example.com"],
                 scopes: ["test"]
               })

      response =
        conn
        |> get(Routes.oauth_server_client_path(conn, :show, client.id))

      assert client_response =
               response
               |> json_response(200)

      assert client_response["client_name"] == client.client_name
      assert client_response["client_id"] == client.id
      assert client_response["client_secret"] == client.client_secret
      assert client_response["redirect_uris"] == client.redirect_uris
    end
  end
end
