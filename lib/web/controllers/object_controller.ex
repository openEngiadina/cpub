defmodule CPub.Web.ObjectController do
  use CPub.Web, :controller

  alias CPub.Object

  action_fallback CPub.Web.FallbackController

  @spec show_by_uuid(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show_by_uuid(%Plug.Conn{} = conn, %{"id" => id_string}) do
    with {:ok, id} <- RDF.UUID.cast(id_string),
         {:ok, object} <- Repo.get_one(Object, id) do
      conn
      |> put_view(RDFView)
      |> render(:show, data: object.content)
    end
  end

  @spec show_by_blake2b(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show_by_blake2b(%Plug.Conn{} = conn, %{"hash" => hash_string}) do
    id = ("urn:blake2b:" <> String.upcase(hash_string)) |> RDF.IRI.new()

    with {:ok, object} <- Repo.get_one(Object, id) do
      conn
      |> put_view(RDFView)
      |> render(:show, data: object.content)
    end
  end
end
