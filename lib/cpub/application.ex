defmodule CPub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  alias CPub.Web.Endpoint

  @spec start(Application.start_type(), term) ::
          {:ok, pid} | {:ok, pid, Application.state()} | {:error, term}
  def start(_type, _args) do
    children = [
      {Task, &log_application_info/0},
      CPub.Web.Endpoint,
      CPub.DB
    ]

    opts = [strategy: :one_for_one, name: CPub.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp log_application_info() do
    with {:ok, version} <- CPub.MixProject.project() |> Keyword.fetch(:version),
         {:ok, source_url} <- CPub.MixProject.project() |> Keyword.fetch(:source_url) do
      Logger.info("Starting CPub (" <> version <> "; " <> source_url <> ")")
    end
  end

  @spec config_change(keyword, keyword, [atom]) :: :ok
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)

    :ok
  end
end
