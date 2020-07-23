defmodule CPub.Web.Authorization.Scope do
  @moduledoc "Defines Authorization scopes"

  use EctoEnum, openid: "openid", read: "read", write: "write"

  import Ecto.Changeset

  def default, do: [:openid, :read, :write]

  @doc """
  Returns true if `scope1` is a subset of `scope2`
  """
  def scope_subset?(scope1, scope2) do
    MapSet.subset?(MapSet.new(scope1), MapSet.new(scope2))
  end
end
