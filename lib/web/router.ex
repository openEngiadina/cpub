defmodule CPub.Web.Router do
  use CPub.Web, :router

  alias CPub.Web.RDFParser

  alias CPub.Web.Authentication
  alias CPub.Web.Authorization

  require Ueberauth

  pipeline :json_api do
    plug :accepts, ["json"]

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Phoenix.json_library()
  end

  pipeline :api do
    plug :accepts, ["rj", "ttl", "json"]

    plug Plug.Parsers,
      parsers: [RDFParser],
      pass: ["*/*"]
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
  end

  # Authentication (only used to accept/deny an OAuth authorization)
  pipeline :session_authentication do
    plug :fetch_session
    plug Authentication.SessionPlug
  end

  # Authorization plug
  pipeline :authorization do
    plug Authorization.AuthorizationPlug
  end

  ## Authentication
  scope "/auth", CPub.Web.Authentication, as: :authentication do
    pipe_through :browser
    pipe_through :session_authentication

    # Session
    get("/login", SessionController, :login)
    post("/login", SessionController, :login)
    get("/session", SessionController, :show)
    post("/logout", SessionController, :logout)

    # Registration
    get("/register", RegistrationController, :register)
    post("/register", RegistrationController, :register)

    # Ueberauth routes for authentication providers
    get("/:provider", ProviderController, :request)
    get("/:provider/callback", ProviderController, :callback)
    post("/:provider/callback", ProviderController, :callback)
  end

  ## OAuth 2.0 server
  scope "/oauth", CPub.Web.Authorization, as: :oauth_server do
    pipe_through :json_api
    pipe_through :session_authentication

    # Endpoint to register clients TODO move this to /oidc/register
    resources("/clients", ClientController, only: [:create, :show])

    # Authorization Endpoint
    get("/authorize", AuthorizationController, :authorize)
    post("/authorize", AuthorizationController, :authorize)

    # Token Endpoint
    post("/token", TokenController, :token)
    # TODO post("/revoke", TokenController, :revoke)
  end

  # TODO
  # scope "/auth", CPub.Web, as: :oauth do
  #   pipe_through :json_api

  #   ## OpenID Connect server
  #   scope [] do
  #     pipe_through :authenticated

  #     get("/userinfo", OIDCController, :user_info)
  #   end
  # scope "/", CPub.Web.OAuth do
  #   ## OpenID Connect server

  #   get("/.well-known/openid-configuration", OIDCController, :provider_metadata)
  #   get("/auth/jwks", OIDCController, :json_web_key_set)

  #   options "/", OIDCController, :authorized_issuer
  #   options "/users/:user_id/me", OIDCController, :authorized_issuer
  # end

  scope "/", CPub.Web do
    pipe_through :api

    resources "/activities", ActivityController, only: [:show]
    get "/objects", ObjectController, :show

    get "/public", PublicController, :get_public
  end

  scope "/users", CPub.Web do
    pipe_through :api
    pipe_through :authorization

    resources "/", UserController, only: [:show] do
      post "/outbox", UserController, :post_to_outbox, as: :outbox
      get "/outbox", UserController, :get_outbox, as: :outbox
      get "/inbox", UserController, :get_inbox, as: :inbox
    end
  end
end
