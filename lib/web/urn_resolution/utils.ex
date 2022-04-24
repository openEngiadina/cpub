# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.URNResolution.Utils do
  @moduledoc """
  Helpers and utils for dealing with URN resolution.
  """

  @spec valid_urn?(any) :: bool
  def valid_urn?(urn) when is_binary(urn) do
    case String.split(urn, ":", parts: 3) do
      ["urn", _, _] -> true
      _ -> false
    end
  end

  def valid_urn?(_), do: false
end
