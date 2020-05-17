defmodule CPub.Web.OAuth.Token.Strategy.Revoke do
  @moduledoc """
  Functions for dealing with revocation strategy.
  """

  alias CPub.Repo
  alias CPub.Web.OAuth.{App, Token}

  @spec revoke(App.t(), map) :: {:ok, Token.t()} | {:error, any}
  def revoke(%App{} = app, %{"access_token" => access_token}) do
    with {:ok, token} <- Token.get_by_access_token(app, access_token), do: revoke(token)
  end

  @spec revoke(Token.t()) :: {:ok, Token.t()} | {:error, Ecto.Changeset.t()}
  def revoke(%Token{} = token), do: Repo.delete(token)
end
