# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.RDFParser do
  @moduledoc """
  Plug to parse `RDF.Graph` from request.
  """

  @behaviour Plug.Parsers

  import RDF.Sigils

  alias RDF.Turtle

  @doc false
  @impl Plug.Parsers
  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @doc false
  @impl Plug.Parsers
  @spec parse(Plug.Conn.t(), String.t(), String.t(), Plug.Conn.Utils.params(), Plug.opts()) ::
          {:ok, Plug.Conn.params(), Plug.Conn.t()}
          | {:error, :too_large, Plug.Conn.t()}
          | {:next, Plug.Conn.t()}
  def parse(%Plug.Conn{} = conn, "text", "turtle", _params, _opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, data} <- Turtle.Decoder.decode(body, base_iri: ~I<http://base-iri.dummy/>),
         skolemized_graph <- RDF.Skolem.skolemize_graph(data) do
      {:ok, %{graph: skolemized_graph}, conn}
    else
      _ ->
        {:next, conn}
    end
  end

  def parse(%Plug.Conn{} = conn, "application", "rdf+json", _params, _opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, data} <- RDF.JSON.Decoder.decode(body, base_iri: ~I<http://base-iri.dummy/>),
         skolemized_graph <- RDF.Skolem.skolemize_graph(data) do
      {:ok, %{graph: skolemized_graph}, conn}
    else
      _ ->
        {:next, conn}
    end
  end
end
