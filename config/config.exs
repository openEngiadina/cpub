# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :cpub,
  namespace: CPub,
  base_url: System.get_env("BASE_URL") || "http://localhost:4000/"

# Configures the endpoint
config :cpub, CPub.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "tohOUv9KpQMbJJ4XMCUhibCzI/kt6yhXXwkeWYCHy+FfDx55PHnkoqAe11nOk6fq",
  render_errors: [view: CPub.Web.ErrorView, accepts: ~w(json)],
  pubsub_server: CPub.PubSub

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Set up mime-type for RDF/Turtle
config :mime, :types, %{"text/turtle" => ["ttl"], "application/rdf+json" => ["rj"]}

# Default prefixes for RDF
config :rdf,
  default_prefixes: %{
    as: "https://www.w3.org/ns/activitystreams#",
    ldp: "http://www.w3.org/ns/ldp#",
    foaf: "http://xmlns.com/foaf/0.1/"
  }

# Authentication providers
config :ueberauth, Ueberauth,
  base_path: "/auth",
  providers: [
    internal: {CPub.Web.Authentication.Strategy.Internal, [callback_methods: ["POST"]]},
    mastodon: {CPub.Web.Authentication.Strategy.Mastodon, []},
    oidc: {CPub.Web.Authentication.Strategy.OIDC, []}
  ]

# Database (mnesia) directory
config :mnesia, dir: System.get_env("CPUB_DATABASE_DIR") || 'db/cpub.#{Mix.env()}'

config :cpub, CPub.Web.Endpoint,
  cookie_signing_salt: "uME3vEPr",
  secure_cookie: true

config :cpub, :instance,
  name: "CPub",
  description: "A semantic ActivityPub server"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
