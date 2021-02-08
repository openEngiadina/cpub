# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.HTTP.Request do
  @moduledoc """
  `CPub.HTTP.Request` struct.
  """

  defstruct method: :get, url: "", query: [], headers: [], body: "", opts: []

  @type method ::
          :get
          | :head
          | :post
          | :put
          | :delete
          | :connect
          | :options
          | :trace
          | :patch

  @type url :: String.t()
  @type headers :: [{String.t(), String.t()}]

  @type t :: %__MODULE__{
          method: method,
          url: url,
          query: keyword,
          headers: headers,
          body: String.t(),
          opts: keyword
        }
end
