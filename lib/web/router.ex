defmodule CPub.Web.Router do
  use CPub.Web, :router

  alias CPub.Web.{
    BasicAuthenticationPlug,
    EnsureAuthenticationPlug,
    OAuthAuthenticationPlug,
    ObjectIDPlug,
    RDFParser
  }

  pipeline :oauth do
    plug :accepts, ["json"]

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Phoenix.json_library()
  end

  pipeline :api do
    plug :accepts, ["rj", "ttl"]
    plug ObjectIDPlug

    plug Plug.Parsers,
      parsers: [RDFParser],
      pass: ["*/*"]
  end

  pipeline :optionally_authenticated do
    # This pipeline authenticates a user but does not fail.
    # This is useful for endpoints that can be accessed by non-authenticated
    # users and authenticated users. But authenticated users get a different
    # response.
    plug :fetch_session
    plug OAuthAuthenticationPlug
    plug BasicAuthenticationPlug
  end

  pipeline :authenticated do
    # This pipeline requires connection to be authenticated.
    # If not a 401 is returned and connection is halted.
    plug :fetch_session
    plug OAuthAuthenticationPlug
    plug BasicAuthenticationPlug
    plug EnsureAuthenticationPlug
  end

  scope "/auth", CPub.Web.OAuth do
    pipe_through :oauth

    ## OAuth server

    post("/apps", AppController, :create)
    get("/apps/verify", AppController, :verify)

    get("/register", OAuthController, :registration_local)
    post("/register", OAuthController, :register)

    get("/authorize", OAuthController, :authorize)
    post("/authorize", OAuthController, :create_authorization)
    get("/login", OAuthController, :login)
    post("/token", OAuthController, :exchange_token)
    post("/revoke", OAuthController, :revoke_token)

    ## OAuth client

    get("/prepare_request", OAuthController, :prepare_request)
    get "/:provider", OAuthController, :handle_request
    get "/:provider/callback", OAuthController, :handle_callback
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

    scope [] do
      pipe_through :authenticated

      get "/id", UserController, :id
      get "/verify", UserController, :verify
    end

    resources "/", UserController, only: [:show] do
      get "/me", UserController, :show_me

      pipe_through :authenticated

      post "/outbox", UserController, :post_to_outbox
      get "/outbox", UserController, :get_outbox
      get "/inbox", UserController, :get_inbox
    end
  end
end
