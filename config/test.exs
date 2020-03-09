use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :cpub, CPub.Web.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :cpub, CPub.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DB") || "cpub_test",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :stream_data,
  # Run every property test for at most 10s in CI and 1.5s otherwise
  max_run_time: if(System.get_env("CI"), do: 10_000, else: 1500)
