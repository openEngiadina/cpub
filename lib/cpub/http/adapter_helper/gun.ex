# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.HTTP.AdapterHelper.Gun do
  @moduledoc false

  @behaviour CPub.HTTP.AdapterHelper

  alias CPub.Config
  alias CPub.HTTP.AdapterHelper

  require Logger

  @type pool :: :federation | :upload | :media | :default

  @defaults [
    retry: 1,
    retry_timeout: 1_000
  ]

  @spec options(keyword, URI.t()) :: keyword
  def options(incoming_opts \\ [], %URI{} = uri) do
    proxy =
      Config.get([:http, :proxy_url])
      |> AdapterHelper.format_proxy()

    config_opts = Config.get([:http, :adapter], [])

    @defaults
    |> Keyword.merge(config_opts)
    |> add_scheme_opts(uri)
    |> AdapterHelper.maybe_add_proxy(proxy)
    |> Keyword.merge(incoming_opts)
    |> put_timeout()
  end

  defp add_scheme_opts(opts, %{scheme: "http"}), do: opts

  defp add_scheme_opts(opts, %{scheme: "https"}) do
    Keyword.put(opts, :certificates_verification, true)
  end

  defp put_timeout(opts) do
    {recv_timeout, opts} = Keyword.pop(opts, :recv_timeout, pool_timeout(opts[:pool]))
    # this is the timeout to receive a message from Gun
    # `:timeout` key is used in Tesla
    Keyword.put(opts, :timeout, recv_timeout)
  end

  @spec pool_timeout(pool) :: non_neg_integer
  def pool_timeout(pool) do
    default = Config.get([:pools, :default, :recv_timeout], 5_000)

    Config.get([:pools, pool, :recv_timeout], default)
  end

  @pool CPub.HTTP.Gun.ConnectionPool
  def limiter_setup do
    wait = Config.get([:connections_pool, :connection_acquisition_wait])
    retries = Config.get([:connections_pool, :connection_acquisition_retries])

    Config.get(:pools, [])
    |> Enum.each(fn {name, opts} ->
      max_running = Keyword.get(opts, :size, 50)
      max_waiting = Keyword.get(opts, :max_waiting, 10)

      result =
        ConcurrentLimiter.new(:"#{@pool}.#{name}", max_running, max_waiting,
          wait: wait,
          max_retries: retries
        )

      case result do
        :ok -> :ok
        {:error, :existing} -> :ok
      end
    end)

    :ok
  end
end
