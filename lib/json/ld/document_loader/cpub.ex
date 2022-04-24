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

  @litepub_url "http://litepub.social/ns#"
  @litepub_data %{
    "@context" => %{
      "litepub" => @litepub_url,
      "oauthRegistrationEndpoint" => %{
        "@id" => "litepub:oauthRegistrationEndpoint",
        "@type" => "@id"
      }
    }
  }

  @spec load(String.t(), Options.t()) :: {:ok, RemoteDocument.t()} | {:error, any}
  def load(@litepub_url, _options) do
    # it's a hack as Litepub context URL is unavailable
    {:ok, %RemoteDocument{document: @litepub_data, document_url: @litepub_url}}
  end

  def load(url, _options) do
    case ConCache.get(:jsonld_context, url) do
      nil ->
        headers = [{"Accept", "application/ld+json"}]

        with {:ok, res} <- HTTP.get(url, headers, []),
             {:ok, data} <- Jason.decode(res.body) do
          :ok = ConCache.put(:jsonld_context, url, data)

          {:ok, %RemoteDocument{document: data, document_url: url}}
        end

      data ->
        {:ok, %RemoteDocument{document: data, document_url: url}}
    end
  end
end
