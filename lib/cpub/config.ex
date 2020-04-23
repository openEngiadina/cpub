defmodule CPub.Config do
  @moduledoc """
  Configuration wrapper.
  """

  @spec base_url :: String.t()
  def base_url, do: get!(:base_url)

  @spec oauth_consumer_strategies :: [String.t()]
  def oauth_consumer_strategies, do: get([:oauth, :consumer_strategies], [])

  @spec oauth_consumer_enabled? :: boolean
  def oauth_consumer_enabled?, do: oauth_consumer_strategies() != []

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
