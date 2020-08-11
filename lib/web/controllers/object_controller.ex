defmodule CPub.Web.ObjectController do
  use CPub.Web, :controller

  alias CPub.Object

  action_fallback CPub.Web.FallbackController

  def get(nil), do: {:error, :bad_request}

  def get("urn:uuid:" <> uuid) do
    with {:ok, id} <- RDF.UUID.cast(uuid) do
      Repo.get_one(Object, id)
    end
  end

  def get("urn:blake2b:" <> hash) do
    id = ("urn:blake2b:" <> String.upcase(hash)) |> RDF.IRI.new()
    Repo.get_one(Object, id)
  end

  def get("urn:erisx:" <> cap) do
    id = ("urn:erisx:" <> String.upcase(cap)) |> RDF.IRI.new()
    Repo.get_one(Object, id)
  end

  def get(_), do: {:error, :not_found}

  def show(%Plug.Conn{} = conn, _) do
    with {:ok, object} <- get(conn.query_params["iri"]) do
      conn
      |> put_view(RDFView)
      |> render(:show, data: object.content)
    end
  end
end
