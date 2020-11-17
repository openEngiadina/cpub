defmodule CPub.Web.ResolveController do
  use CPub.Web, :controller

  alias CPub.ERIS

  action_fallback CPub.Web.FallbackController

  def get("urn:erisx2:" <> _ = urn), do: ERIS.get_rdf(urn)
  def get(nil), do: {:error, :bad_request}
  def get(_), do: {:error, :not_found}

  def show(%Plug.Conn{} = conn, _) do
    with {:ok, object} <- get(conn.query_params["iri"]) do
      conn
      |> put_view(RDFView)
      |> render(:show, data: object)
    end
  end
end
