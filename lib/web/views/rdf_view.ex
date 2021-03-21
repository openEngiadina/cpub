# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.RDFView do
  @moduledoc """
  A generic view for anything that implements the `RDF.Data` protocol.
  """

  use CPub.Web, :view

  @spec render(String.t(), map) :: String.t() | map
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
