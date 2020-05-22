defmodule CPub.Web.OAuth.Authenticator do
  @moduledoc """
  Util functions for authentication.
  """

  alias CPub.{Registration, User}
  alias CPub.Web.BasicAuthenticationPlug

  @spec get_user(Plug.Conn.t(), map) :: {:ok, User.t()} | {:error, any}
  def get_user(%Plug.Conn{} = conn, params) do
    with {:ok, {username, password}} <- fetch_credentials(conn, params),
         %User{} = user <- User.get_by(%{username: username, provider: "local"}),
         {:ok, user} <- checkpw(user, password) do
      {:ok, user}
    else
      _ ->
        {:error, :invalid_credentials}
    end
  end

  @spec create_user_from_registration(Registration.t(), map) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user_from_registration(
        %Registration{} = registration,
        %{"authorization" => %{"provider" => "local", "password" => password}}
      ) do
    user_attrs = %{username: registration.username, password: password}

    {:ok, user} = User.create(user_attrs)
    {:ok, _} = Registration.bind_to_user(registration, user)

    {:ok, user}
  end

  def create_user_from_registration(
        %Registration{} = registration,
        %{"authorization" => %{"provider" => provider}}
      ) do
    user_attrs = %{username: registration.username, provider: provider}

    {:ok, user} = User.create_from_provider(user_attrs)
    {:ok, _} = Registration.bind_to_user(registration, user)

    {:ok, user}
  end

  @spec fetch_credentials(Plug.Conn.t(), map) :: {:ok, {String.t(), String.t()}} | {:error, atom}
  defp fetch_credentials(%Plug.Conn{} = conn, params) do
    # Per RFC 6749, HTTP Basic is preferred to body params
    case BasicAuthenticationPlug.fetch_credentials(conn) do
      {username, password} ->
        {:ok, {username, password}}

      nil ->
        case params do
          %{"authorization" => %{"username" => username, "password" => password}} ->
            {:ok, {username, password}}

          %{"grant_type" => "password", "username" => username, "password" => password} ->
            {:ok, {username, password}}

          _ ->
            {:error, :invalid_credentials}
        end
    end
  end

  @spec checkpw(User.t(), String.t()) :: {:ok, User.t()} | {:error, String.t()}
  defp checkpw(%User{} = user, password) do
    Pbkdf2.check_pass(user, password, hash_key: :password)
  end
end
