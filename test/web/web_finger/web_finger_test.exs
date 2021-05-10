# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.WebFingerTest do
  @moduledoc false

  use ExUnit.Case
  use CPub.Web.ConnCase
  use CPub.DataCase

  alias CPub.Config
  alias CPub.User

  alias CPub.Web.Authorization
  alias CPub.Web.Authorization.Token
  alias CPub.Web.Path
  alias CPub.Web.WebFinger

  doctest CPub.Web.WebFinger

  setup do
    with {:ok, user} <- User.create("alice"),
         {:ok, authorization} <- Authorization.create(user, [:read, :write]),
         {:ok, token} <- Token.create(authorization) do
      {:ok, %{user: user, token: token}}
    end
  end

  describe "account/2" do
    test "returns account descriptor", %{user: user} do
      account = "#{user.username}@#{URI.parse(Config.base_url()).host}"
      user_uri = Path.user(user)

      assert {:ok, desc} = WebFinger.account(account, %{})

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
             } == desc
    end

    test "returns account descriptor with issuer", %{user: user} do
      account = "#{user.username}@#{URI.parse(Config.base_url()).host}"
      user_uri = Path.user(user)
      auth_login_uri = Path.authentication_session_login()

      assert {:ok, desc} =
               WebFinger.account(account, %{"rel" => "http://openid.net/specs/connect/1.0/issuer"})

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
             } == desc
    end

    test "returns error for unknown account" do
      assert {:error, _} = WebFinger.account("unknown", %{})
    end
  end
end
