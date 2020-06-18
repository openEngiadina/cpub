defmodule CPub.Web.ObjectIDPlug do
  @moduledoc """
  Plug to cast the request URL to a valid ID (IRI) and assign to connection.
  This is useful as the id for an object being accessed is usually the request url.
  """

  import Plug.Conn

  alias CPub.Config

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(%Plug.Conn{request_path: request_path} = conn, _opts) do
    {:ok, id} =
      Config.base_url()
      |> URI.merge(request_path)
      |> Map.put(:query, nil)
      |> URI.to_string()
      |> CPub.ID.cast()

    assign(conn, :id, id)
  end
end
