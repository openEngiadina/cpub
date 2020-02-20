defmodule CPubWeb.Authentication do
  @moduledoc """
  Authentication helpers
  """

  use CPubWeb, :controller

  @doc """
  Verify username and password and assign user to connection or halt connection.
  """
  def verify_user(conn, username, password) do
    case CPub.User.verify_user(username, password) do
      {:ok, user} ->
        conn
        |> assign(:user, user)

      _ ->
        conn
        |> halt
    end
  end
end
