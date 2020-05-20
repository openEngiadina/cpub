defmodule CPub.Web.OAuth.FallbackController do
  use CPub.Web, :controller

  alias CPub.Web.OAuth.OAuthController

  @spec call(Plug.Conn.t(), tuple) :: Plug.Conn.t()
  def call(conn, {:register, :generic_error}) do
    conn
    |> put_status(:internal_server_error)
    |> put_flash(:error, "Unknown error, please check the details and try again.")
    |> OAuthController.registration_from_provider(conn.params)
  end

  def call(conn, {:register, :password_confirmation}) do
    conn
    |> put_status(:unauthorized)
    |> put_flash(:error, "Invalid password confirmation.")
    |> OAuthController.registration_local(conn.params)
  end

  def call(conn, {:register, %Ecto.Changeset{errors: [username: {message, _}]}}) do
    conn
    |> put_status(:unauthorized)
    |> put_flash(:error, "Username #{message}")
    |> OAuthController.registration_local(conn.params)
  end

  def call(conn, {:register, _error}) do
    conn
    |> put_status(:unauthorized)
    |> put_flash(:error, "Invalid credentials.")
    |> OAuthController.registration_from_provider(conn.params)
  end

  def call(conn, _error) do
    conn
    |> put_status(:unauthorized)
    |> put_flash(:error, "Invalid credentials.")
    |> OAuthController.authorize(conn.params)
  end
end
