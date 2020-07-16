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

  @doc """
  Register a new user with a registration_request (external registration).
  """
  def register(%Plug.Conn{method: "GET"} = conn, %{"request" => request_token}) do
    with {:ok, request_id} <-
           Token.verify(conn, "registration_request", request_token, max_age: 86400),
         {:ok, request} <- Repo.get_one(RegistrationRequest, request_id) do
      request |> IO.inspect()

      conn
      |> render_external_registration_form(request: request, request_token: request_token)
    end
  end

  def register(%Plug.Conn{method: "POST"} = conn, %{
        "request" => request_token,
        "username" => username
      }) do
    with {:ok, request_id} <-
           Token.verify(conn, "registration_request", request_token, max_age: 86400),
         {:ok, request} <- Repo.get_one(RegistrationRequest, request_id),
         {:ok, %{user: user}} <- Registration.create(username, request) do
      conn
      |> SessionController.create_session(user)
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
end
