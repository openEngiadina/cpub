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

    # TODO/NOTE This is not working properly.
    # If authentication fails (can not decode credentials or invalid username/password) the Authentication.Basic plug halts the pipeline. When this happens an error is raised by cowboy. I think because halt does not work as I expect and downstream plugs attempt to send a response even though a response is already sent.
    plug CPubWeb.Authentication.Basic
  end

  scope "/", CPubWeb do
    pipe_through :api

    resources "/objects", LDP.RDFSourceController, only: [:index, :show]
    resources "/containers", LDP.BasicContainerController, only: [:show]

    resources "/users", UserController, only: [:show] do
      get "/inbox", LDP.BasicContainerController, :show
      get "/outbox", LDP.BasicContainerController, :show
      post "/outbox", ActivityPub.OutboxController, :post
    end

  end

end
