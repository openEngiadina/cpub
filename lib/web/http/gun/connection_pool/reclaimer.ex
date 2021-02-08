# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Web.HTTP.Gun.ConnectionPool.Reclaimer do
  @moduledoc false

  use GenServer, restart: :temporary

  alias CPub.Config
  alias CPub.Web.HTTP.Gun
  alias CPub.Web.HTTP.Gun.ConnectionPool.WorkerSupervisor

  @registry Gun.ConnectionPool

  def start_monitor do
    pid =
      case :gen_server.start(__MODULE__, [], name: {:via, Registry, {@registry, "reclaimer"}}) do
        {:ok, pid} -> pid
        {:error, {:already_registered, pid}} -> pid
      end

    {pid, Process.monitor(pid)}
  end

  @impl true
  def init(_) do
    {:ok, nil, {:continue, :reclaim}}
  end

  @impl true
  def handle_continue(:reclaim, _) do
    max_connections = Config.get([:connections_pool, :max_connections])

    reclaim_max =
      Config.get([:connections_pool, :reclaim_multiplier])
      |> Kernel.*(max_connections)
      |> round
      |> max(1)

    :telemetry.execute([:cpub, :connection_pool, :reclaim, :start], %{}, %{
      max_connections: max_connections,
      reclaim_max: reclaim_max
    })

    unused_conns =
      Registry.select(
        @registry,
        [{{:_, :"$1", {:_, :"$2", :"$3", :"$4"}}, [{:==, :"$2", []}], [{{:"$1", :"$3", :"$4"}}]}]
      )

    case unused_conns do
      [] ->
        :telemetry.execute(
          [:cpub, :connection_pool, :reclaim, :stop],
          %{reclaimed_count: 0},
          %{max_connections: max_connections}
        )

        {:stop, :no_unused_conns, nil}

      unused_conns ->
        reclaimed =
          unused_conns
          |> Enum.sort(fn {_pid1, crf1, last_reference1}, {_pid2, crf2, last_reference2} ->
            crf1 <= crf2 and last_reference1 <= last_reference2
          end)
          |> Enum.take(reclaim_max)

        Enum.each(reclaimed, fn {pid, _, _} ->
          DynamicSupervisor.terminate_child(WorkerSupervisor, pid)
        end)

        :telemetry.execute(
          [:cpub, :connection_pool, :reclaim, :stop],
          %{reclaimed_count: Enum.count(reclaimed)},
          %{max_connections: max_connections}
        )

        {:stop, :normal, nil}
    end
  end
end
