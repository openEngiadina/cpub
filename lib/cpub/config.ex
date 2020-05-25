defmodule CPub.Config do
  @moduledoc """
  Configuration wrapper.
  """

  alias CPub.Web.Endpoint
  alias CPub.Web.OAuth.Strategy.OIDC

  # Common

  @spec base_url :: String.t()
  def base_url, do: get!(:base_url)

  @spec instance :: keyword
  def instance, do: get!(:instance)

  ## Auth

  @spec cookie_secure? :: boolean
  def cookie_secure?, do: get([Endpoint, :secure_cookie])

  @spec cookie_name :: String.t()
  def cookie_name, do: if(cookie_secure?(), do: "__Host-cpub_key", else: "_cpub_key")

  @spec cookie_signing_salt :: String.t()
  def cookie_signing_salt, do: get([Endpoint, :cookie_signing_salt], "uME3vEPr")

  @spec cookie_extra_attrs :: String.t()
  def cookie_extra_attrs, do: get([Endpoint, :cookie_extra_attrs], []) |> Enum.join(";")

  @spec auth_consumer_strategies :: [String.t()]
  def auth_consumer_strategies, do: get([:auth, :consumer_strategies], [])

  @spec auth_consumer_strategies_names :: keyword
  def auth_consumer_strategies_names, do: get([:auth, :consumer_strategies_names], [])

  @spec auth_multi_instances_consumer_strategies :: [String.t()]
  def auth_multi_instances_consumer_strategies, do: ["oidc_cpub", "pleroma", "cpub"]

  @spec auth_consumer_enabled? :: boolean
  def auth_consumer_enabled?, do: auth_consumer_strategies() != []

  @spec oauth2_token_expires_in :: integer
  def oauth2_token_expires_in, do: get([:auth, :oauth2_token_expires_in], 60 * 60)

  @spec oauth2_issue_new_refresh_token :: boolean
  def oauth2_issue_new_refresh_token, do: get([:auth, :oauth2_issue_new_refresh_token], false)

  @spec oauth2_provider_opts(String.t()) :: keyword
  def oauth2_provider_opts(provider) do
    {module, _} = Application.get_env(:ueberauth, Ueberauth)[:providers][:"#{provider}"]
    Application.get_env(:ueberauth, :"#{module}.OAuth")
  end

  @spec oidc_provider_opts(String.t()) :: keyword
  def oidc_provider_opts(oidc_provider) do
    Application.get_env(:ueberauth, OIDC.OAuth)[:"oidc_#{oidc_provider}"]
  end

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
