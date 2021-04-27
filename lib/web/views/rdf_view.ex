# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.RDFView do
  @moduledoc """
  A generic view for anything that implements the `RDF.Data` protocol.
  """

  use CPub.Web, :view

  alias JSON.LD.DocumentLoader
  alias JSON.LD.Encoder.CPub, as: CPubEncoder

  @spec render(String.t(), map) :: String.t() | map
  @dialyzer {:nowarn_function, render: 2}
  def render("show.jsonld", %{data: %RDF.FragmentGraph{} = data}) do
    CPubEncoder.encode!(data)
  end

  def render("show.jsonld", %{data: data}) do
    JSON.LD.Encoder.encode!(data, document_loader: DocumentLoader.CPub)
  end

  def render("show.json", %{data: data}) do
    RDF.JSON.Encoder.from_rdf!(data)
  end

  def render("show.rj", %{data: data}) do
    RDF.JSON.Encoder.encode!(data)
  end

  def render("show.ttl", %{data: data}) do
    RDF.Turtle.Encoder.encode!(data)
  end
end
