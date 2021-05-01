# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Magnet do
  @moduledoc """
  Magnet URIs builder.
  """

  alias RDF.FragmentGraph

  alias CPub.Web.Path

  @spec from_urn(String.t()) :: String.t()
  def from_urn(urn) do
    with urn_resolution_path <- Path.urn_resolution(%Plug.Conn{}, "N2R", urn),
         magnet_params <- %{info_hash: [urn], source: [urn_resolution_path]},
         magnet <- struct(Magnet, magnet_params) do
      Magnet.encode(magnet)
    end
  end

  @spec from_eris_read_capability(ERIS.ReadCapability.t()) :: String.t()
  def from_eris_read_capability(%ERIS.ReadCapability{} = read_capability) do
    read_capability
    |> ERIS.ReadCapability.to_string()
    |> from_urn()
  end

  @spec fragment_graph_finalizer(FragmentGraph.t()) :: String.t()
  def fragment_graph_finalizer(%FragmentGraph{} = fg) do
    fg
    |> FragmentGraph.eris_finalizer()
    |> from_urn()
  end
end
