# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
# SPDX-FileCopyrightText: 2017-2021 Pleroma Authors <https://pleroma.social/>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.HTTP.AdapterHelper do
  @moduledoc """
  Configure Tesla.Client with default and customized adapter options.
  """

  require Logger

  @type proxy_type :: :socks4 | :socks5
  @type host :: charlist | :inet.ip_address()

  @type proxy ::
          {host, pos_integer}
          | {proxy_type, host, pos_integer}

  @defaults [pool: :federation, connect_timeout: 5_000, recv_timeout: 5_000]

  @callback options(keyword, URI.t()) :: keyword

  @spec format_proxy(String.t() | tuple | nil) :: proxy | nil
  def format_proxy(nil), do: nil

  def format_proxy(proxy_url) do
    case parse_proxy(proxy_url) do
      {:ok, host, port} -> {host, port}
      {:ok, type, host, port} -> {type, host, port}
      _ -> nil
    end
  end

  @spec maybe_add_proxy(keyword, proxy | nil) :: keyword
  def maybe_add_proxy(opts, nil), do: opts
  def maybe_add_proxy(opts, proxy), do: Keyword.put_new(opts, :proxy, proxy)

  @doc """
  Merge default connection & adapter options with received ones.
  """
  @spec options(URI.t(), keyword) :: keyword
  def options(%URI{} = uri, opts \\ []) do
    @defaults
    |> Keyword.merge(opts)
    |> adapter_helper().options(uri)
  end

  @spec parse_proxy(String.t() | tuple | nil) ::
          {:ok, host, pos_integer}
          | {:ok, proxy_type, host, pos_integer}
          | {:error, atom}
          | nil
  def parse_proxy(nil), do: nil

  def parse_proxy(proxy) when is_binary(proxy) do
    with [host, port] <- String.split(proxy, ":"),
         {port, ""} <- Integer.parse(port) do
      {:ok, parse_host(host), port}
    else
      {_, _} ->
        Logger.warn("Parsing port failed #{inspect(proxy)}")
        {:error, :invalid_proxy_port}

      :error ->
        Logger.warn("Parsing port failed #{inspect(proxy)}")
        {:error, :invalid_proxy_port}

      _ ->
        Logger.warn("Parsing proxy failed #{inspect(proxy)}")
        {:error, :invalid_proxy}
    end
  end

  def parse_proxy(proxy) when is_tuple(proxy) do
    case proxy do
      {type, host, port} ->
        {:ok, type, parse_host(host), port}

      _ ->
        Logger.warn("Parsing proxy failed #{inspect(proxy)}")

        {:error, :invalid_proxy}
    end
  end

  @spec parse_host(String.t() | atom | charlist) :: charlist | :inet.ip_address()
  def parse_host(host) when is_list(host), do: host
  def parse_host(host) when is_atom(host), do: to_charlist(host)

  def parse_host(host) when is_binary(host) do
    host = to_charlist(host)

    case :inet.parse_address(host) do
      {:error, :einval} -> host
      {:ok, ip} -> ip
    end
  end

  @spec format_host(String.t()) :: charlist
  def format_host(host) do
    host_charlist = to_charlist(host)

    case :inet.parse_address(host_charlist) do
      {:error, :einval} ->
        :idna.encode(host_charlist)

      {:ok, _ip} ->
        host_charlist
    end
  end

  @spec adapter :: module
  defp adapter, do: Application.get_env(:tesla, :adapter)

  @spec adapter_helper :: module
  defp adapter_helper do
    case adapter() do
      Tesla.Adapter.Gun -> __MODULE__.Gun
      _ -> __MODULE__.Default
    end
  end
end
