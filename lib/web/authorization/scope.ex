defmodule CPub.Web.Authorization.Scope do
  @moduledoc "Defines Authorization scopes"

  use EctoEnum, openid: "openid", read: "read", write: "write"

  import Ecto.Changeset

  def default, do: [:openid, :read, :write]
end
