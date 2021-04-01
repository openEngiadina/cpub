# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Config do
  @moduledoc """
  Configuration wrapper.
  """

  alias CPub.Web.Endpoint

  # Common

  @spec base_url :: String.t()
  def base_url, do: get!(:base_url)

  @spec host :: String.t()
  def host, do: Endpoint.host()

  @spec instance :: keyword
  def instance, do: get!(:instance)

  @spec user_agent :: String.t()
  def user_agent do
    if Process.whereis(Endpoint) do
      case get([:http, :user_agent], :default) do
        :default ->
          "#{CPub.Application.named_version()}; #{base_url()} <#{instance()[:email]}>"

        custom ->
          custom
      end
    else
      # fallback, if endpoint is not started yet
      CPub.Application.named_version()
    end
  end

  ## Auth

  @spec cookie_secure? :: boolean
  def cookie_secure?, do: get([Endpoint, :secure_cookie])

  @spec cookie_name :: String.t()
  def cookie_name, do: if(cookie_secure?(), do: "__Host-cpub_key", else: "_cpub_key")

  @spec cookie_signing_salt :: String.t()
  def cookie_signing_salt, do: get([Endpoint, :cookie_signing_salt], "uME3vEPr")

  @spec cookie_extra_attrs :: String.t()
  def cookie_extra_attrs, do: get([Endpoint, :cookie_extra_attrs], []) |> Enum.join(";")

  # Util

  @spec get(atom | module) :: any
  def get(key) when is_atom(key), do: get(key, nil)

  @spec get([atom | module]) :: any
  def get([key]), do: get(key, nil)
  def get([_ | _] = keys), do: get(keys, nil)

  @spec get([atom | module], any) :: any
  def get([key], default), do: get(key, default)

  def get([parent_key | keys], default) do
    case parent_key |> get() |> get_in(keys) do
      nil -> default
      value -> value
    end
  end

  @spec get(atom | module, any) :: any
  def get(key, default), do: Application.get_env(:cpub, key, default)

  @spec get!(atom | module) :: any
  def get!(key) do
    value = get(key, nil)

    if value == nil do
      raise("Missing configuration value: #{inspect(key)}")
    else
      value
    end
  end
end
