# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.JSONView do
  @moduledoc """
  A generic view for a blob of JSON
  """

  use CPub.Web, :view

  def render("show.json", %{data: data}) do
    data
  end
end
