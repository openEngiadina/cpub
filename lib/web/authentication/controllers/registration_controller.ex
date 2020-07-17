defmodule CPub.Web.Authentication.RegistrationController do
  @moduledoc """
  Implements interactive user registration.
  """

  use CPub.Web, :controller

  alias CPub.Repo
  alias CPub.User

  alias CPub.Web.Authentication.Registration
  alias CPub.Web.Authentication.RegistrationRequest
  alias CPub.Web.Authentication.SessionController

  alias Phoenix.Token

  action_fallback CPub.Web.FallbackController

  defp get_request(conn, request_token) do
    with {:ok, request_id} <-
           Token.verify(conn, "registration_request", request_token, max_age: 86_400) do
      Repo.get_one(RegistrationRequest, request_id)
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
    with {:ok, request} <- get_request(conn, request_token) do
      case Registration.create(username, request) do
        {:ok, %{user: user}} ->
          conn
          |> SessionController.create_session(user)

        _ ->
          conn
          |> put_flash(:error, "Registration failed.")
          |> render_external_registration_form(request: request, request_token: request_token)
      end
    end
  end

  # Local registration

  def register(%Plug.Conn{method: "GET"} = conn, _params) do
    conn
    |> render_local_registration_form(username: nil)
  end

  def register(%Plug.Conn{method: "POST"} = conn, %{
        "username" => username,
        "password" => password
      }) do
    case User.create(%{username: username, password: password}) do
      {:ok, user} ->
        conn
        |> SessionController.create_session(user)

      _ ->
        conn
        |> put_flash(:error, "Registration failed.")
        |> render_local_registration_form(username: username)
    end
  end

  defp render_external_registration_form(conn, request: request, request_token: request_token) do
    conn
    |> render("external_registration.html",
      callback_url:
        Routes.authentication_registration_path(conn, :register, request: request_token),
      registration_external_id: request.external_id,
      username: request.info["username"]
    )
  end

  defp render_local_registration_form(conn, username: username) do
    conn
    |> render("local_registration.html",
      callback_url: Routes.authentication_registration_path(conn, :register),
      username: username
    )
  end
end
