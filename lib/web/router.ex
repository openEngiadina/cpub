defmodule CPub.Web.Router do
  use CPub.Web, :router

  alias CPub.Web.RDFParser

  alias CPub.Web.Authentication
  alias CPub.Web.OAuthServer

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

  # Authentication (only used to accept/deny an OAuth authorization)
  pipeline :session_authentication do
    plug :fetch_session
    plug Authentication.SessionPlug
  end

  # Authorization plug
  pipeline :authorization do
    plug OAuthServer.AuthorizationPlug
  end

  ## Authentication
  scope "/auth", CPub.Web.Authentication, as: :authentication do
    pipe_through :json_api
    pipe_through :session_authentication

    # Authenticate user with a HTML form
    get("/login", AuthenticationController, :login, as: "")
    post("/login", AuthenticationController, :login, as: "")

    # TODO
    # post("/logout", AuthenticationController, :logout)
  end

  ## OAuth 2.0 server
  scope "/oauth", CPub.Web.OAuthServer, as: :oauth_server do
    pipe_through :json_api
    pipe_through :session_authentication

    # Endpoint to register clients TODO move this to /oidc/register
    resources("/clients", ClientController, only: [:create, :show])

    # Authorization Endpoint
    get("/authorize", AuthorizationController, :authorize)
    post("/authorize", AuthorizationController, :authorize)

    # Token Endpoint
    post("/token", TokenController, :token)
  end

  # scope "/auth", CPub.Web, as: :oauth do
  #   pipe_through :json_api

  #   ## OpenID Connect server
  #   scope [] do
  #     pipe_through :authenticated

  #     get("/userinfo", OIDCController, :user_info)
  #   end

  #   get("/register", OAuthController, :registration_local)
  #   post("/register", OAuthController, :register)

  #   get("/authorize", OAuthController, :authorize)

  #   post("/authorize", OAuthController, :create_authorization)
  #   get("/login", OAuthController, :login)

  #   post("/token", OAuthController, :exchange_token)
  #   post("/revoke", OAuthController, :revoke_token)

  #   ## OAuth client
  #   get("/prepare_request", OAuthController, :prepare_request)
  #   get "/:provider", OAuthController, :handle_request
  #   get "/:provider/callback", OAuthController, :handle_callback
  # end

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

    scope [] do
      get "/id", UserController, :id
      get "/verify", UserController, :verify
    end

    resources "/", UserController, only: [:show] do
      post "/outbox", UserController, :post_to_outbox, as: :outbox
      get "/outbox", UserController, :get_outbox, as: :outbox
      get "/inbox", UserController, :get_inbox, as: :inbox
    end
  end
end
