# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.URNResolution.URNResolutionController do
  @moduledoc """
  Implements URN Resolution endpoints (https://tools.ietf.org/html/rfc2169).
  """

  use CPub.Web, :controller

  import CPub.Web.URNResolution.Utils

  alias CPub.Web.URNResolution

  action_fallback CPub.Web.FallbackController

  @services ["N2R"]

  @spec resolve(Plug.Conn.t(), map) :: Plug.Conn.t()
  def resolve(%Plug.Conn{} = conn, %{"service" => service}) do
    with true <- service in @services,
         [urn] <- Map.keys(conn.query_params),
         true <- valid_urn?(urn) do
      case String.upcase(service) do
        "N2R" -> resource(conn, urn)
      end
    else
      _ ->
        {:error, :bad_request}
    end
  end

  @spec resource(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  defp resource(%Plug.Conn{} = conn, urn) do
    case URNResolution.name_to_resource(urn) do
      {:ok, resource} ->
        conn
        |> put_view(RDFView)
        |> render(:show, data: resource)

      _ ->
        {:error, :not_found}
    end
  end
end
