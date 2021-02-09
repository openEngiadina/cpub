# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.HTTP.Tesla.Middleware.ConnectionPool do
  @moduledoc """
  Middleware to get/release connections from `CPub.HTTP.Gun.ConnectionPool`
  """

  @behaviour Tesla.Middleware

  alias CPub.HTTP.Gun.ConnectionPool

  @impl Tesla.Middleware
  def call(%Tesla.Env{url: url, opts: opts} = env, next, _) do
    uri = URI.parse(url)

    # Avoid leaking connections when the middleware is called twice
    # with body_as: :chunks. We assume only the middleware can set
    # opts[:adapter][:conn]
    if opts[:adapter][:conn] do
      ConnectionPool.release_conn(opts[:adapter][:conn])
    end

    case ConnectionPool.get_conn(uri, opts[:adapter]) do
      {:ok, conn_pid} ->
        adapter_opts = Keyword.merge(opts[:adapter], conn: conn_pid, close_conn: false)
        opts = Keyword.put(opts, :adapter, adapter_opts)
        env = %{env | opts: opts}

        run_tesla(conn_pid, env, next, opts)

      error ->
        error
    end
  end

  defp run_tesla(conn_pid, env, next, opts) do
    case Tesla.run(env, next) do
      {:ok, env} ->
        if opts[:adapter][:body_as] != :chunks do
          ConnectionPool.release_conn(conn_pid)
          {_, res} = pop_in(env.opts[:adapter][:conn])

          {:ok, res}
        else
          {:ok, env}
        end

      error ->
        ConnectionPool.release_conn(conn_pid)

        error
    end
  end
end
