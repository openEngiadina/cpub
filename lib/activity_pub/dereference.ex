# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.ActivityPub.Dereference do
  @moduledoc """
  Implements strategies for dereferencing known types of URIs:
  - URL,
  - ERIS URN,
  - Magnet URN.
  """

  alias JSON.LD.Decoder
  alias JSON.LD.DocumentLoader

  @type uri :: String.t() | RDF.IRI.t()

  @spec fetch(uri | [uri]) :: {:ok, RDF.FragmentGraph.t()} | {:error, any}
  def fetch(uri) when is_binary(uri), do: dereference(URI.parse(uri).scheme, uri)

  def fetch(%RDF.IRI{} = uri) do
    with uri <- to_string(uri), do: dereference(URI.parse(uri).scheme, uri)
  end

  def fetch([uri]) when is_binary(uri), do: fetch(uri)

  def fetch(uris) when is_list(uris) do
    uris
    |> Task.async_stream(&fetch/1, timeout: 3_000, on_timeout: :kill_task)
    |> Enum.reduce_while({:error, :not_found}, fn res, acc ->
      case res do
        {:ok, {:ok, fragment_graph}} ->
          {:halt, {:ok, fragment_graph}}

        {:ok, {:error, _reason}} ->
          {:cont, acc}

        {:exit, _reason} ->
          {:cont, acc}
      end
    end)
  end

  @spec dereference(String.t(), String.t()) :: {:ok, RDF.FragmentGraph.t()} | {:error, any}
  defp dereference(http, url) when http in ["http", "https"] do
    with {:ok, %Tesla.Env{status: 200, body: body}} <-
           CPub.HTTP.get(url, [{"Accept", "application/ld+json"}]),
         {:ok, data} <- Decoder.decode(body, document_loader: DocumentLoader.CPub),
         skolemized_graph <- RDF.Skolem.skolemize_graph(data),
         fragment_graph <- RDF.FragmentGraph.new(skolemized_graph) do
      {:ok, fragment_graph}
    else
      {:ok, %Tesla.Env{status: 404}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dereference("urn", "urn:eris" <> _ = urn) do
    case CPub.ERIS.get_rdf(urn) do
      {:ok, fragment_graph} ->
        {:ok, fragment_graph}

      {:error, _} ->
        {:error, :not_found}
    end
  end

  defp dereference("urn", _), do: {:error, :unknown_urn_nid}

  defp dereference("magnet", magnet_uri) do
    case Magnet.decode(magnet_uri) do
      {:ok, %Magnet{info_hash: [urn], source: urls}} ->
        case dereference("urn", urn) do
          {:ok, fragment_graph} ->
            {:ok, fragment_graph}

          {:error, reason} when reason in [:not_found, :unknown_urn_nid] ->
            fetch(urls)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dereference(_, _), do: {:error, :unknown_uri_scheme}
end
