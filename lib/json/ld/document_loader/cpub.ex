# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule JSON.LD.DocumentLoader.CPub do
  @moduledoc """
  Customized `JSON.LD.DocumentLoader` which uses `CPub.HTTP` to get remote
  contexts.
  """

  @behaviour JSON.LD.DocumentLoader

  alias JSON.LD.DocumentLoader.RemoteDocument
  alias JSON.LD.Options

  alias CPub.HTTP

  @spec load(String.t(), Options.t()) :: {:ok, RemoteDocument.t()} | {:error, any}
  def load(url, _options) do
    headers = [{"Accept", "application/ld+json"}]

    with {:ok, res} <- HTTP.get(url, headers, []),
         {:ok, data} <- Jason.decode(res.body) do
      {:ok, %RemoteDocument{document: data, document_url: url}}
    end
  end
end
