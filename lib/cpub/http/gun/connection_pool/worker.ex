# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.HTTP.Gun.ConnectionPool.Worker do
  @moduledoc false

  use GenServer, restart: :temporary

  alias CPub.Config
  alias CPub.HTTP.Gun

  @registry Gun.ConnectionPool

  @spec start_link(keyword) :: GenServer.on_start()
  def start_link([key | _] = opts) do
    GenServer.start_link(__MODULE__, opts, name: {:via, Registry, {@registry, key}})
  end

  @impl true
  def init([_key, _uri, _opts, _client_pid] = opts) do
    {:ok, nil, {:continue, {:connect, opts}}}
  end

  @impl true
  def handle_continue({:connect, [key, uri, opts, client_pid]}, _) do
    with {:ok, conn_pid, protocol} <- Gun.Conn.open(uri, opts),
         true <- Process.link(conn_pid) do
      time = :erlang.monotonic_time(:millisecond)

      {_, _} =
        Registry.update_value(@registry, key, fn _ -> {conn_pid, [client_pid], 1, time} end)

      send(client_pid, {:conn_pid, conn_pid})

      {:noreply,
       %{
         key: key,
         timer: nil,
         client_monitors: %{client_pid => Process.monitor(client_pid)},
         protocol: protocol
       }, :hibernate}
    else
      error ->
        {:stop, {:shutdown, error}, nil}
    end
  end

  @impl true
  def handle_cast({:add_client, client_pid}, state) do
    with {:reply, conn_pid, state, :hibernate} <-
           handle_call(:add_client, {client_pid, nil}, state) do
      send(client_pid, {:conn_pid, conn_pid})

      {:noreply, state, :hibernate}
    end
  end

  @impl true
  def handle_cast({:remove_client, client_pid}, state) do
    with {:reply, _, state, :hibernate} <-
           handle_call(:remove_client, {client_pid, nil}, state) do
      {:noreply, state, :hibernate}
    end
  end

  @impl true
  def handle_call(:add_client, {client_pid, _}, %{key: key, protocol: protocol} = state) do
    time = :erlang.monotonic_time(:millisecond)

    {{conn_pid, used_by, _, _}, _} =
      Registry.update_value(@registry, key, fn {conn_pid, used_by, crf, last_reference} ->
        {conn_pid, [client_pid | used_by], crf(time - last_reference, crf), time}
      end)

    :telemetry.execute(
      [:cpub, :connection_pool, :client, :add],
      %{client_pid: client_pid, clients: used_by},
      %{key: state.key, protocol: protocol}
    )

    state =
      if state.timer != nil do
        _ = Process.cancel_timer(state[:timer])

        %{state | timer: nil}
      else
        state
      end

    ref = Process.monitor(client_pid)

    state = put_in(state.client_monitors[client_pid], ref)

    {:reply, conn_pid, state, :hibernate}
  end

  @impl true
  def handle_call(:remove_client, {client_pid, _}, %{key: key} = state) do
    {{_conn_pid, used_by, _crf, _last_reference}, _} =
      Registry.update_value(@registry, key, fn {conn_pid, used_by, crf, last_reference} ->
        {conn_pid, List.delete(used_by, client_pid), crf, last_reference}
      end)

    {ref, state} = pop_in(state.client_monitors[client_pid])

    Process.demonitor(ref, [:flush])

    timer =
      if used_by == [] do
        max_idle = Config.get([:connections_pool, :max_idle_time], 30_000)

        Process.send_after(self(), :idle_close, max_idle)
      else
        nil
      end

    {:reply, :ok, %{state | timer: timer}, :hibernate}
  end

  @impl true
  def handle_info(:idle_close, state) do
    # Gun monitors the owner process, and will close the connection automatically
    # when it's terminated
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:gun_up, _pid, _protocol}, state) do
    {:noreply, state, :hibernate}
  end

  # Gracefully shutdown if the connection got closed without any streams left
  @impl true
  def handle_info({:gun_down, _pid, _protocol, _reason, []}, state) do
    case Map.keys(state.client_monitors) do
      [] ->
        {:stop, :normal, state}

      _pids ->
        {:noreply, state, :hibernate}
    end
  end

  # Otherwise, wait for retry
  @impl true
  def handle_info({:gun_down, _pid, _protocol, _reason, _killed_streams}, state) do
    {:noreply, state, :hibernate}
  end

  @impl true
  def handle_info({:gun_tunnel_up, _pid, _stream_ref, _protocol}, state) do
    {:noreply, state, :hibernate}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    :telemetry.execute(
      [:cpub, :connection_pool, :client, :dead],
      %{client_pid: pid, reason: reason},
      %{key: state.key}
    )

    handle_cast({:remove_client, pid}, state)
  end

  # LRFU policy: https://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.55.1478
  defp crf(time_delta, prev_crf) do
    1 + :math.pow(0.5, 0.0001 * time_delta) * prev_crf
  end
end
