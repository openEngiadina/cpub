defmodule CPubWeb.Router do
  use CPubWeb, :router

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

    resources "/objects", ObjectController, only: [:index, :show]
    resources "/containers", LDP.BasicContainerController, only: [:show]

    resources "/actors", ActivityPub.ActorController, only: [:show, :create] do
      get "/inbox", LDP.BasicContainerController, :show

      get "/outbox", LDP.BasicContainerController, :show
      post "/outbox", ActivityPub.ActorController, :post_to_outbox
    end

  end

end
