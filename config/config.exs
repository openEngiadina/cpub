# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :cpub,
  namespace: CPub,
  ecto_repos: [CPub.Repo],
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

# Configure external authentication providers (OAuth2, OIDC and Solid)
# auth_consumer_strategies =
#   System.get_env("AUTH_CONSUMER_STRATEGIES")
#   |> to_string()
#   |> String.split()
#   |> Enum.map(&hd(String.split(&1, ":")))

# ueberauth_providers =
#   auth_consumer_strategies
#   |> Enum.filter(&(not (&1 in ["solid", "cpub", "pleroma"] || String.starts_with?(&1, "oidc"))))
#   |> Enum.map(fn strategy ->
#     strategy_module_name = "Elixir.Ueberauth.Strategy.#{String.capitalize(strategy)}"
#     strategy_module = String.to_atom(strategy_module_name)
#     {String.to_atom(strategy), {strategy_module, []}}
#   end)

config :ueberauth, Ueberauth,
  base_path: "/auth",
  providers: [
    local: {CPub.Web.Authentication.Strategy.Local, [callback_methods: ["POST"]]}
  ]

# config :cpub, :auth,
#   consumer_strategies: auth_consumer_strategies,
#   consumer_strategies_names: [
#     solid: "Solid (WebID-OIDC)",
#     oidc_cpub: "CPub (OIDC)",
#     # oidc_gitlab: "GitLab (OIDC)",
#     # oidc_microsoft: "Microsoft (OIDC)",
#     cpub: "CPub",
#     pleroma: "Pleroma / Mastodon"
#     # github: "GitHub",
#     # gitlab: "GitLab",
#     # discord: "Discord"
#   ],
#   token_expires_in: 60 * 60,
#   issue_new_refresh_token: true

# Password hashing function
# Use Pbkdf2 because it does not require any C code
config :comeonin, Ecto.Password, Pbkdf2

config :cpub, CPub.Web.Endpoint,
  cookie_signing_salt: "uME3vEPr",
  secure_cookie: true

config :cpub, :instance,
  name: "CPub",
  description: "A semantic ActivityPub server"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
