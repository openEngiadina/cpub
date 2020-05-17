defmodule CPub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias CPub.Web.Endpoint
  alias CPub.Web.OAuth.App

  @spec start(Application.start_type(), term) ::
          {:ok, pid} | {:ok, pid, Application.state()} | {:error, term}
  def start(_type, _args) do
    children =
      [
        CPub.Repo,
        CPub.Web.Endpoint
      ] ++
        cachex_children()

    opts = [strategy: :one_for_one, name: CPub.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    {:ok, _} = App.get_or_create_local_app()

    {:ok, pid}
  end

  @spec config_change(keyword, keyword, [atom]) :: :ok
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)

    :ok
  end

  @spec cachex_children :: [map]
  defp cachex_children do
    [cachex_spec(:user, default_ttl: 25_000, ttl_interval: 1000, limit: 2500)]
  end

  @spec cachex_spec(atom | String.t(), keyword) :: map
  defp cachex_spec(name, opts) do
    %{
      id: :"cachex_#{name}",
      start: {Cachex, :start_link, [:"#{name}_cache", opts]},
      type: :worker
    }
  end
end
