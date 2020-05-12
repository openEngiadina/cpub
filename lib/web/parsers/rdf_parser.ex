defmodule CPub.Web.RDFParser do
  @moduledoc """
  Plug to parse `RDF.Graph` from request.
  """
  @behaviour Plug.Parsers

  alias RDF.{Turtle}
  import RDF.Sigils

  @doc false
  @impl Plug.Parsers
  @spec init(opts :: Keyword.t()) :: Plug.opts()
  def init(opts) do
    opts
  end

  @doc false
  @impl Plug.Parsers
  @spec parse(
          conn :: Plug.Conn.t(),
          type :: binary(),
          subtype :: binary(),
          params :: Plug.Conn.Utils.params(),
          opts :: Plug.opts()
        ) ::
          {:ok, Plug.Conn.params(), Plug.Conn.t()}
          | {:error, :too_large, Plug.Conn.t()}
          | {:next, Plug.Conn.t()}
  def parse(conn, "text", "turtle", _params, _opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, data} <- Turtle.Decoder.decode(body, base_iri: ~I<http://base-iri.dummy/>),
         skolemized_graph <- data |> RDF.Skolem.skolemize_graph() do
      {:ok, %{graph: skolemized_graph}, conn}
    end
  end

  def parse(conn, "application", "rdf+json", _params, _opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, data} <- RDF.JSON.Decoder.decode(body, base_iri: ~I<http://base-iri.dummy/>),
         skolemized_graph <- data |> RDF.Skolem.skolemize_graph() do
      {:ok, %{graph: skolemized_graph}, conn}
    end
  end
end
