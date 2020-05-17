defmodule CPub.Web.OAuth.Authenticator do
  @moduledoc """
  Util functions for authentication.
  """

  alias CPub.{Registration, User}
  alias CPub.Web.OAuth.App

  @spec get_user(Plug.Conn.t()) :: {:ok, User.t()} | {:error, any}
  def get_user(%Plug.Conn{} = conn) do
    with {:ok, {username, password}} <- fetch_credentials(conn),
         %User{} = user <- User.get_by(%{username: username, provider: "local"}),
         {:ok, user} <- checkpw(user, password) do
      {:ok, user}
    else
      _ ->
        {:error, :invalid_credentials}
    end
  end

  @spec create_user_from_registration(Plug.Conn.t(), Registration.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user_from_registration(
        %Plug.Conn{params: %{"authorization" => registration_params}},
        %Registration{} = registration
      ) do
    provider =
      case registration_params["provider"] do
        "" -> App.get_provider(registration_params["state"])
        provider -> provider
      end

    user_attrs = %{username: registration.username, provider: provider}

    with {:ok, user} <- User.create_from_provider(user_attrs),
         {:ok, _} <- Registration.bind_to_user(registration, user) do
      {:ok, user}
    end
  end

  @spec fetch_credentials(Plug.Conn.t() | map) ::
          {:ok, {String.t(), String.t()}} | {:error, :invalid_credentials}
  def fetch_credentials(%Plug.Conn{params: params}), do: fetch_credentials(params)

  def fetch_credentials(params) do
    case params do
      %{"authorization" => %{"username" => username, "password" => password}} ->
        {:ok, {username, password}}

      %{"grant_type" => "password", "username" => username, "password" => password} ->
        {:ok, {username, password}}

      _ ->
        {:error, :invalid_credentials}
    end
  end

  @spec checkpw(User.t(), String.t()) :: {:ok, User.t()} | {:error, String.t()}
  def checkpw(%User{} = user, password) do
    Pbkdf2.check_pass(user, password, hash_key: :password)
  end
end
