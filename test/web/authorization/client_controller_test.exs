defmodule CPub.Web.Authorization.ClientControllerTest do
  use ExUnit.Case
  use CPub.Web.ConnCase

  doctest CPub.Web.Authorization.ClientController

  describe "create/2" do
    test "creates a new client", %{conn: conn} do
      response =
        conn
        |> post(Routes.oauth_server_client_path(conn, :create), %{
          client_name: "Test Client",
          redirect_uris: ["http://example.com/"],
          scope: ["read", "write"] |> Enum.join(" ")
        })

      assert %{
               "client_name" => "Test Client",
               "redirect_uris" => ["http://example.com/"],
               "scope" => "read write"
             } =
               response
               |> json_response(201)
    end
  end
end
