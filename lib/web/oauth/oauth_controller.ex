defmodule CPub.Web.OAuth.OAuthController do
  use CPub.Web, :controller

  alias CPub.{Config, User}
  alias CPub.Web.OAuth.App
  alias Ueberauth.{Auth, Failure}

  if Config.oauth_consumer_enabled?(), do: plug(Ueberauth)

  @doc """
  Handles those authorization requests which can not be handled by registered
  Ueberauth strategies.
  """
  @spec handle_request(Plug.Conn.t(), map) :: Plug.Conn.t()
  def handle_request(%Plug.Conn{} = conn, %{"provider" => provider}) do
    message =
      if provider do
        "Unsupported OAuth provider: #{provider}."
      else
        "Bad OAuth request."
      end

    conn
    |> send_resp(:bad_request, message)
    |> halt()
  end

  @doc """
  Handles successful authorization and registers a new user from external OAuth
  provider.
  """
  @spec handle_callback(Plug.Conn.t(), map) :: Plug.Conn.t()
  def handle_callback(
        %Plug.Conn{assigns: %{ueberauth_auth: %Auth{info: %Auth.Info{} = info}}} = conn,
        %{"provider" => provider} = params
      ) do
    username = info.nickname || info.name
    provider = if params["state"], do: App.get_provider(params["state"]), else: provider

    case User.get_user(username, provider) do
      %User{} = user ->
        conn
        |> assign(:user, user)
        |> put_view(RDFView)
        |> render(:show, data: user.profile)

      nil ->
        case User.create_from_provider(%{username: username, provider: provider}) do
          {:ok, %User{} = user} ->
            conn
            |> assign(:user, user)
            |> put_view(RDFView)
            |> render(:show, data: user.profile)

          {:error, _} ->
            conn
            |> send_resp(:bad_request, "User can not be registered.")
            |> halt()
        end
    end
  end

  @doc """
  Handles a failure from external OAuth provider.
  """
  @spec handle_callback(Plug.Conn.t(), map) :: Plug.Conn.t()
  def handle_callback(
        %Plug.Conn{
          assigns: %{
            ueberauth_failure: %Failure{
              errors: [%Failure.Error{message_key: message_key, message: message} | _]
            }
          }
        } = conn,
        _params
      ) do
    conn
    |> send_resp(:bad_request, "#{message_key}: #{message}")
    |> halt()
  end
end
