# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.WebFinger.WebFingerControllerTest do
  @moduledoc false

  use ExUnit.Case
  use CPub.Web.ConnCase
  use CPub.DataCase

  alias CPub.Config
  alias CPub.User

  alias CPub.Web.Authorization
  alias CPub.Web.Authorization.Token
  alias CPub.Web.Path

  doctest CPub.Web.WebFinger.WebFingerController

  setup do
    with {:ok, user} <- User.create("alice"),
         {:ok, authorization} <- Authorization.create(user, [:read, :write]),
         {:ok, token} <- Token.create(authorization) do
      {:ok, %{user: user, token: token}}
    end
  end

  describe "resource/2" do
    test "returns account descriptor", %{conn: conn, user: user} do
      account = "#{user.username}@#{URI.parse(Config.base_url()).host}"
      user_uri = Path.user(conn, user)

      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get(Routes.web_finger_path(conn, :resource, %{"resource" => "acct:#{account}"}))

      assert response.status == 200
      assert {:ok, response} = Jason.decode(response.resp_body)

      assert %{
               "subject" => "acct:#{account}",
               "aliases" => [user_uri],
               "links" => [
                 %{
                   "rel" => "http://webfinger.net/rel/profile-page",
                   "type" => "text/html",
                   "href" => user_uri
                 },
                 %{
                   "rel" => "self",
                   "type" => "application/activity+json",
                   "href" => user_uri
                 },
                 %{
                   "rel" => "self",
                   "type" =>
                     "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"",
                   "href" => user_uri
                 }
               ]
             } == response
    end

    test "returns account descriptor with issuer", %{conn: conn, user: user} do
      account = "#{user.username}@#{URI.parse(Config.base_url()).host}"
      user_uri = Path.user(conn, user)
      auth_login_uri = Path.authentication_session_login(conn)

      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get(
          Routes.web_finger_path(conn, :resource, %{
            "resource" => "acct:#{account}",
            "rel" => "http://openid.net/specs/connect/1.0/issuer"
          })
        )

      assert response.status == 200
      assert {:ok, response} = Jason.decode(response.resp_body)

      assert %{
               "subject" => "acct:#{account}",
               "aliases" => [user_uri],
               "links" => [
                 %{
                   "rel" => "http://webfinger.net/rel/profile-page",
                   "type" => "text/html",
                   "href" => user_uri
                 },
                 %{
                   "rel" => "self",
                   "type" => "application/activity+json",
                   "href" => user_uri
                 },
                 %{
                   "rel" => "self",
                   "type" =>
                     "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"",
                   "href" => user_uri
                 },
                 %{
                   "rel" => "http://openid.net/specs/connect/1.0/issuer",
                   "href" => auth_login_uri
                 }
               ]
             } == response
    end

    test "returns 404 for unknown resource", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get(Routes.web_finger_path(conn, :resource, %{"resource" => "acct:unknown"}))

      assert response.status == 404
    end
  end
end
