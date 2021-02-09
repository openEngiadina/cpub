# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.HTTP.AdapterHelper.Default do
  @moduledoc false

  @behaviour CPub.HTTP.AdapterHelper

  alias CPub.Config
  alias CPub.HTTP.AdapterHelper

  @spec options(keyword, URI.t()) :: keyword
  def options(opts, _uri) do
    proxy = Config.get([:http, :proxy_url])

    AdapterHelper.maybe_add_proxy(opts, AdapterHelper.format_proxy(proxy))
  end

  @spec get_conn(URI.t(), keyword) :: {:ok, keyword}
  def get_conn(_uri, opts), do: {:ok, opts}
end
