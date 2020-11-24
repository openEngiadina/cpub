defmodule CPub.Web.Authentication.RegistrationController do
  @moduledoc """
  Implements interactive user registration.
  """

  use CPub.Web, :controller

  alias CPub.DB
  alias CPub.User

  alias CPub.Web.Authentication.RegistrationRequest
  alias CPub.Web.Authentication.SessionController

  alias Phoenix.Token

  action_fallback CPub.Web.FallbackController

  # External registration

  defp get_request(conn, request_token) do
    with {:ok, request_id} <-
           Token.verify(conn, "registration_request", request_token, max_age: 86_400) do
      RegistrationRequest.get(request_id)
    end
  end

  @doc """
  Register a new user with a registration_request (external registration).
  """
  def register(%Plug.Conn{method: "GET"} = conn, %{"request" => request_token}) do
    with {:ok, request} <- get_request(conn, request_token) do
      conn
      |> render_external_registration_form(request: request, request_token: request_token)
    end
  end

  def register(%Plug.Conn{method: "POST"} = conn, %{
        "request" => request_token,
        "username" => username
      }) do
    case get_request(conn, request_token) do
      {:ok, request} ->
        with {:ok, user} <- User.create(username),
             {:ok, _registration} <-
               User.Registration.create_external(
                 user,
                 request.provider,
                 request.site,
                 request.external_id
               ) do
          conn
          |> SessionController.create_session(user)
        else
          {:error, :user_already_exists} ->
            conn
            |> put_flash(:error, "username not available")
            |> render_external_registration_form(request: request, request_token: request_token)

          _ ->
            conn
            |> put_flash(:error, "Registration failed.")
        end

      _ ->
        conn
        |> put_flash(:error, "Registration failed.")
    end
  end

  # Internal registration

  def register(%Plug.Conn{method: "GET"} = conn, _params) do
    conn
    |> render_internal_registration_form(username: nil)
  end

  # Helper that creates a user with internal registration
  defp create_user_with_internal_registration(username, password) do
    DB.transaction(fn ->
      with {:ok, user} <- User.create(username),
           {:ok, _registration} <- User.Registration.create_internal(user, password) do
        user
      end
    end)
  end

  def register(%Plug.Conn{method: "POST"} = conn, %{
        "username" => username,
        "password" => password
      }) do
    case create_user_with_internal_registration(username, password) do
      {:ok, user} ->
        conn
        |> SessionController.create_session(user)

      _ ->
        conn
        |> put_flash(:error, "Registration failed.")
        |> render_internal_registration_form(username: username)
    end
  end

  # Render helpers

  defp render_external_registration_form(conn, request: request, request_token: request_token) do
    conn
    |> render("external_registration.html",
      callback_url:
        Routes.authentication_registration_path(conn, :register, request: request_token),
      registration_external_id: request.external_id,
      username: request.username
    )
  end

  defp render_internal_registration_form(conn, username: username) do
    conn
    |> render("internal_registration.html",
      callback_url: Routes.authentication_registration_path(conn, :register),
      username: username
    )
  end
end
