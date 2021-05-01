# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.URNResolution do
  @moduledoc """
  Implement URN Resolution protocol as described in RFC 2169.

  A Trivial Convention for using HTTP in URN Resolution:
  https://tools.ietf.org/html/rfc2169.

  Supports [content-addressed
  RDF](https://openengiadina.net/papers/content-addressable-rdf.html) that is
  encoded with [ERIS](https://inqlab.net/projects/eris/).
  """

  alias RDF.FragmentGraph

  alias CPub.ERIS

  @spec name_to_resource(String.t()) :: {:ok, FragmentGraph.t()} | {:error, any}
  def name_to_resource(urn), do: ERIS.get_rdf(urn)
end
