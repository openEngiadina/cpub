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
  base_url: "http://localhost:4000/"

# Configures the endpoint
config :cpub, CPub.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "tohOUv9KpQMbJJ4XMCUhibCzI/kt6yhXXwkeWYCHy+FfDx55PHnkoqAe11nOk6fq",
  render_errors: [view: CPubWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: CPub.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Set up mime-type for RDF/Turtle
config :mime, :types, %{"text/turtle" => ["ttl"]}

# Configure CORS
config :cors_plug, origin: ["*"]

# Default prefixes for RDF
config :rdf,
  default_prefixes: %{
    as: "http://www.w3.org/ns/activitystreams#",
    ldp: "http://www.w3.org/ns/ldp#"
  }

#

# Password hashing function
# Use Pbkdf2 because it does not require any C code
config :comeonin, Ecto.Password, Pbkdf2

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
