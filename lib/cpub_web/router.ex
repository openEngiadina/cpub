defmodule CPubWeb.Router do
  use CPubWeb, :router

  @doc """
  Cast the request URL to a valid ID (IRI) and assign to connection.

  This is useful as the id for an object being accessed is usually the request url.
  """
  def assign_id(conn, _opts) do
    case request_url(conn) |> CPub.ID.cast() do
      {:ok, id} ->
        conn
        |> assign(:id, id)
      _ ->
        conn
    end
  end

  pipeline :api do
    plug :accepts, ["json", "ttl"]
    plug :assign_id
  end

  scope "/", CPubWeb do
    pipe_through :api

    resources "/objects", LDP.RDFSourceController, only: [:index, :show]
    resources "/activities", LDP.RDFSourceController, only: [:show]
    resources "/containers", LDP.BasicContainerController, only: [:show]

    resources "/users", UserController, only: [:show] do
      get "/inbox", LDP.BasicContainerController, :show
      get "/outbox", LDP.BasicContainerController, :show
      post "/outbox", ActivityPub.OutboxController, :post
    end

  end

end
