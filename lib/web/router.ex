defmodule CPub.Web.Router do
  use CPub.Web, :router

  alias CPub.Web.{AuthenticationPlug, EnsureAuthenticationPlug}

  @doc """
  Cast the request URL to a valid ID (IRI) and assign to connection.

  This is useful as the id for an object being accessed is usually the request url.
  """
  @spec assign_id(Plug.Conn.t(), Plug.opts()) :: Plug.opts()
  def assign_id(conn, _opts) do
    # Major hack: TODO fix.
    request_url =
      String.replace_suffix(Application.get_env(:cpub, :base_url), "/", "") <>
        conn.request_path

    case request_url |> CPub.ID.cast() do
      {:ok, id} ->
        assign(conn, :id, id)

      _ ->
        conn
    end
  end

  pipeline :api do
    plug :accepts, ["json", "ttl"]

    plug Plug.Parsers,
      parsers: [CPub.Web.RDFParser],
      pass: ["*/*"]

    plug :assign_id
  end

  pipeline :optionally_authenticated do
    # This pipeline authenticates a user but does not fail.
    # This is useful for endpoints that can be accessed by non-authenticated
    # users and authenticated users. But authenticated users get a different
    # response.
    plug AuthenticationPlug
  end

  pipeline :authenticated do
    # This pipeline requires connection to be authenticated.
    # If not a 401 is returned and connection is halted.
    plug EnsureAuthenticationPlug
  end

  scope "/", CPub.Web do
    pipe_through :api

    resources "/activities", ActivityController, only: [:show]
    resources "/objects", ObjectController, only: [:show]
    get "/public", PublicController, :get_public
  end

  scope "/users", CPub.Web do
    pipe_through :api
    pipe_through :optionally_authenticated

    resources "/", UserController, only: [:show] do
      pipe_through :authenticated
      post "/outbox", UserController, :post_to_outbox
      get "/outbox", UserController, :get_outbox
      get "/inbox", UserController, :get_inbox
    end
  end
end
