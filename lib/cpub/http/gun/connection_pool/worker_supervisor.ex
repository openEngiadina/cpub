# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.HTTP.Gun.ConnectionPool.WorkerSupervisor do
  @moduledoc """
  Supervisor for pool workers. Does not do anything except enforce max
  connection limit.
  """

  use DynamicSupervisor

  alias CPub.Config
  alias CPub.HTTP.Gun.ConnectionPool.Reclaimer
  alias CPub.HTTP.Gun.ConnectionPool.Worker

  @spec start_link(any) :: Supervisor.on_start()
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec init(any) :: {:ok, DynamicSupervisor.sup_flags()}
  def init(_opts) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: Config.get([:connections_pool, :max_connections])
    )
  end

  @spec start_worker(keyword, bool) :: DynamicSupervisor.on_start_child() | {:error, any}
  def start_worker(opts, retry \\ false) do
    case DynamicSupervisor.start_child(__MODULE__, {Worker, opts}) do
      {:error, :max_children} ->
        if retry or free_pool() == :error do
          :telemetry.execute([:cpub, :connection_pool, :provision_failure], %{opts: opts})

          {:error, :pool_full}
        else
          start_worker(opts, true)
        end

      result ->
        result
    end
  end

  @spec free_pool :: :ok | :error
  defp free_pool do
    wait_for_reclaimer_finish(Reclaimer.start_monitor())
  end

  @spec wait_for_reclaimer_finish({pid, reference}) :: :ok | :error
  defp wait_for_reclaimer_finish({pid, mon}) do
    receive do
      {:DOWN, ^mon, :process, ^pid, :no_unused_conns} -> :error
      {:DOWN, ^mon, :process, ^pid, :normal} -> :ok
    end
  end
end
