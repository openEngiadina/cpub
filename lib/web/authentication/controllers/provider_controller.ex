defmodule CPub.Web.Authentication.ProviderController do
  @moduledoc """
  Implements interactive user authentication by means of different providers.

  If authentication is successfull a `CPub.Web.Authentication.Session` will be stored in the `Plug.Session`.
  """
  use CPub.Web, :controller

  alias CPub.Web.Authentication.Registration
  alias CPub.Web.Authentication.RegistrationRequest
  alias CPub.Web.Authentication.Strategy

  alias CPub.Web.Authentication.SessionController

  alias Ueberauth.Strategy.Helpers

  alias Phoenix.Token

  action_fallback CPub.Web.FallbackController

  plug Ueberauth, provider: [:local]

  def request(%Plug.Conn{} = conn, %{"provider" => "local"}) do
    conn
    |> render("local.html",
      callback_url: Helpers.callback_path(conn),
      username: conn.params["username"],
      on_success: conn.params["on_success"]
    )
  end

  # go back to session login on failure
  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> redirect(
      to: Routes.authentication_session_path(conn, :login, error: "Failed to authenticate.")
    )
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case auth.strategy do
      Strategy.Local ->
        conn
        |> SessionController.create_session(auth.extra.raw_info.user)

      Ueberauth.Strategy.Pleroma ->
        # If user is already registered create a session an succeed
        with {:ok, registration} <- Registration.get_from_auth(auth) do
          conn
          |> SessionController.create_session(registration.user)
        else
          # if not create a registration requeset and redirect user to register form
          _ ->
            with {:ok, registration_request} <- RegistrationRequest.create(auth),
                 registration_token <-
                   Token.sign(conn, "registration_request", registration_request.id) do
              conn
              |> redirect(
                to:
                  Routes.authentication_registration_path(conn, :register,
                    request: registration_token
                  )
              )
            end
        end
    end
  end
end
