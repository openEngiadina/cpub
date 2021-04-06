# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.NodeInfo do
  @moduledoc """
  NodeInfo metadata exposing protocol
  (see https://github.com/jhass/nodeinfo/blob/main/PROTOCOL.md).
  """

  alias CPub.Config

  @type version :: :"2.0" | :"2.1"

  @type software :: %{
          required(:name) => String.t(),
          required(:version) => String.t(),
          optional(:repository) => String.t(),
          optional(:homepage) => String.t()
        }

  @type protocol ::
          :activitypub
          | :buddycloud
          | :dfrn
          | :diaspora
          | :libertree
          | :ostatus
          | :pumpio
          | :tent
          | :xmpp
          | :zot

  @type inbound_service ::
          :"atom1.0"
          | :gnusocial
          | :imap
          | :pnut
          | :pop3
          | :pumpio
          | :"rss2.0"
          | :twitter

  @type outbound_service ::
          :"atom1.0"
          | :blogger
          | :buddycloud
          | :diaspora
          | :dreamwidth
          | :drupal
          | :facebook
          | :friendica
          | :gnusocial
          | :google
          | :insanejournal
          | :libertree
          | :linkedin
          | :livejournal
          | :mediagoblin
          | :myspace
          | :pinterest
          | :pnut
          | :posterous
          | :pumpio
          | :redmatrix
          | :"rss2.0"
          | :smtp
          | :tent
          | :tumblr
          | :twitter
          | :wordpress
          | :xmpp

  @type services :: %{
          required(:inbound) => [inbound_service],
          required(:outbound) => [outbound_service]
        }

  @type users :: %{
          optional(:total) => non_neg_integer,
          optional(:activeHalfyear) => non_neg_integer,
          optional(:activeMonth) => non_neg_integer
        }

  @type usage :: %{
          required(:users) => users,
          optional(:localPosts) => non_neg_integer,
          optional(:localComments) => non_neg_integer
        }

  @type t :: %{
          required(:version) => version,
          required(:software) => software,
          required(:protocols) => [protocol],
          required(:services) => services,
          required(:openRegistration) => boolean,
          required(:usage) => usage,
          required(:medadata) => map
        }

  @spec get_node_info(String.t()) :: t | :error
  @dialyzer {:nowarn_function, get_node_info: 1}
  def get_node_info("2.0") do
    %{
      version: "2.0",
      software: %{
        name: CPub.Application.name() |> String.downcase(),
        version: CPub.Application.version()
      },
      protocols: [:activitypub],
      services: %{
        inbound: [],
        outbound: []
      },
      openRegistrations: Config.instance()[:open_registrations],
      usage: %{
        users: %{
          # TODO Count total number of users
          total: 0
        }
      },
      # TODO Add metadata
      metadata: %{}
    }
  end

  def get_node_info("2.1") do
    node_info = get_node_info("2.0")

    updated_software =
      node_info
      |> Map.get(:software)
      |> Map.put(:repository, CPub.Application.repository())

    node_info
    |> Map.put(:software, updated_software)
    |> Map.put(:version, :"2.1")
  end

  def get_node_info(_), do: :error
end
