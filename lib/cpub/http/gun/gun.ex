# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.HTTP.Gun do
  @moduledoc false

  @type host ::
          String.t()
          | {byte, byte, byte, byte}
          | {char, char, char, char, char, char}

  @api __MODULE__.API

  @callback open(charlist, pos_integer, map) :: {:ok, pid}
  @callback info(pid) :: map
  @callback close(pid) :: :ok
  @callback await_up(pid, pos_integer) :: {:ok, atom} | {:error, atom}
  @callback connect(pid, map) :: reference
  @callback await(pid, reference) :: {:response, :fin, 200, []}
  @callback set_owner(pid, pid) :: :ok

  @spec open(host, non_neg_integer, map) :: {:ok, pid} | {:error, any}
  def open(host, port, opts), do: api().open(host, port, opts)

  @spec info(pid) :: map
  def info(pid), do: api().info(pid)

  @spec close(pid) :: :ok
  def close(pid), do: api().close(pid)

  @spec await_up(pid, non_neg_integer) :: {:ok, atom} | {:error, atom}
  def await_up(pid, timeout \\ 5_000), do: api().await_up(pid, timeout)

  @spec connect(pid, map) :: reference
  def connect(pid, opts), do: api().connect(pid, opts)

  @spec await(pid, reference) :: any
  def await(pid, ref), do: api().await(pid, ref)

  @spec set_owner(pid, pid) :: :ok
  def set_owner(pid, owner), do: api().set_owner(pid, owner)

  @spec api :: module
  defp api, do: @api
end
