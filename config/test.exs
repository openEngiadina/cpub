use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :cpub, CPubWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :cpub, CPub.Repo,
  username: "postgres",
  password: "postgres",
  database: "cpub_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
