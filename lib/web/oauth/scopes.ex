defmodule CPub.Web.OAuth.Scopes do
  @moduledoc """
  Util functions for dealing with scopes.
  """

  @doc """
  Fetches scopes from request params.
  Note: `scope` is OAuth standard, `scopes` is used by Mastodon/Pleroma.
  """
  @spec fetch_scopes(map, [String.t()]) :: [String.t()]
  def fetch_scopes(params, default) do
    parse_scopes(params["scope"] || params["scopes"], default)
  end

  @doc """
  Validates scopes.
  """
  @spec validate([String.t()] | nil, [String.t()]) :: {:ok, [String.t()]} | {:error, atom}
  def validate(blank_scopes, _app_scopes) when blank_scopes in [nil, []] do
    {:error, :missing_scopes}
  end

  def validate(scopes, app_scopes) do
    case filter_descendants(scopes, app_scopes) do
      ^scopes -> {:ok, scopes}
      _ -> {:error, :unsupported_scopes}
    end
  end

  @spec filter_descendants([String.t()], [String.t()]) :: [String.t()]
  def filter_descendants(scopes, supported_scopes) do
    Enum.filter(scopes, fn scope ->
      Enum.find(supported_scopes, &(scope == &1 || String.starts_with?(scope, &1 <> ":")))
    end)
  end

  @spec parse_scopes([String.t()] | String.t(), [String.t()]) :: [String.t()]
  defp parse_scopes(scopes, default) when is_binary(scopes) do
    scopes
    |> to_list()
    |> parse_scopes(default)
  end

  defp parse_scopes(scopes, _default) when is_list(scopes) do
    Enum.filter(scopes, &(&1 not in [nil, ""]))
  end

  defp parse_scopes(_, default), do: default

  @spec to_string([String.t()]) :: String.t()
  def to_string(scopes), do: Enum.join(scopes, " ")

  @spec to_list(String.t()) :: [String.t()]
  def to_list(nil), do: []

  def to_list(str) do
    str
    |> String.trim()
    |> String.split(~r/[\s,]+/)
  end
end
