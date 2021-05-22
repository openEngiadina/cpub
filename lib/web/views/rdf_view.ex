# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.RDFView do
  @moduledoc """
  A generic view for anything that implements the `RDF.Data` protocol.
  """

  use CPub.Web, :view

  alias JSON.LD.Encoder.ActivityPub, as: CPubEncoder

  alias CPub.NS.ActivityStreams, as: AS

  @spec render(String.t(), map) :: String.t() | map
  @dialyzer {:nowarn_function, render: 2}
  def render("show.jsonld", %{data: %RDF.FragmentGraph{} = data}) do
    CPubEncoder.compact_encode!(data)
  end

  def render("show.jsonld", %{data: data}) do
    CPubEncoder.compact_encode!(data)
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

  @spec sort_by_published(MapSet.t()) :: [ERIS.ReadCapability.t()]
  def sort_by_published(objects) do
    objects
    |> Enum.to_list()
    |> Task.async_stream(&CPub.ERIS.get_rdf/1)
    |> Enum.sort_by(
      &with {:ok, {:ok, rdf}} <- &1 do
        rdf.statements[AS.published()] |> Enum.to_list() |> List.first() |> RDF.Literal.value()
      end,
      &(NaiveDateTime.compare(&1, &2) == :gt)
    )
    |> Enum.map(
      &with {:ok, {:ok, fg}} <- &1,
            {:ok, eris} <- fg.base_subject |> to_string() |> ERIS.ReadCapability.parse() do
        eris
      end
    )
  end
end
