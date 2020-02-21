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

  pipeline :authenticated do
    plug BasicAuth, callback: &CPubWeb.Authentication.verify_user/3
  end

  scope "/", CPubWeb do
    pipe_through :api

    resources "/activities", ActivityController, only: [:show]
    resources "/objects", ObjectController, only: [:show]
    get "/public", PublicController, :get_public

  end

  scope "/users", CPubWeb do
    pipe_through :api
    pipe_through :authenticated

    resources "/", UserController, only: [:show] do
      post "/outbox", UserController, :post_to_outbox
      get "/outbox", UserController, :get_outbox
      get "/inbox", UserController, :get_inbox
    end

  end

end
