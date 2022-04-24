# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.WebFinger do
  @moduledoc """
  WebFinger discovery protocol.

  Support:
  - Actor profile URIs discovery for Mastodon API interoperability
    (see https://docs.joinmastodon.org/spec/webfinger/).
  - Identity Provider discovery for OpenID Connect
    (see https://tools.ietf.org/html/rfc7033#section-3.1);
  """

  alias CPub.Config
  alias CPub.User

  alias CPub.Web.Path

  @open_id_connect_issuer "http://openid.net/specs/connect/1.0/issuer"
  @profile_page "http://webfinger.net/rel/profile-page"
  @activity_streams "https://www.w3.org/ns/activitystreams"

  @spec account(String.t(), map) :: {:ok, map} | {:error, any}
  def account(account, opts) do
    host = URI.parse(Config.base_url()).host
    regex = ~r/^(?<username>[a-z0-9A-Z_\.-]+)@#{host}$/

    with %{"username" => username} <- Regex.named_captures(regex, account),
         {:ok, %User{} = user} <- User.get(username) do
      {:ok, descriptor(user, opts)}
    else
      _ ->
        {:error, :account_not_found}
    end
  end

  @spec descriptor(User.t(), map) :: map
  @dialyzer {:nowarn_function, descriptor: 2}
  defp descriptor(%User{} = user, opts) do
    %{
      "subject" => subject(user),
      "aliases" => descriptor_aliases(user),
      "links" => descriptor_links(user) ++ opts_links(opts)
    }
  end

  @spec subject(User.t()) :: String.t()
  defp subject(%User{} = user) do
    "acct:#{user.username}@#{URI.parse(Config.base_url()).host}"
  end

  @spec descriptor_aliases(User.t()) :: [String.t()]
  @dialyzer {:nowarn_function, descriptor_aliases: 1}
  defp descriptor_aliases(%User{} = user), do: [Path.user(user)]

  @spec descriptor_links(User.t()) :: [map]
  defp descriptor_links(%User{} = user) do
    user_uri = Path.user(user)

    [
      %{
        "rel" => @profile_page,
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
        "type" => "application/ld+json; profile=\"#{@activity_streams}\"",
        "href" => user_uri
      }
    ]
  end

  @spec opts_links(map) :: [map]
  defp opts_links(%{"rel" => @open_id_connect_issuer}) do
    [
      %{
        "rel" => @open_id_connect_issuer,
        "href" => Path.authentication_session_login()
      }
    ]
  end

  defp opts_links(_), do: []
end
