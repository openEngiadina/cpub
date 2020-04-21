defmodule CPub.Web.OAuthController do
  use CPub.Web, :controller

  alias CPub.User
  alias Ueberauth.Auth

  plug Ueberauth

  @spec request(Plug.Conn.t(), map) :: Plug.Conn.t()
  def request(%Plug.Conn{} = conn, %{"provider" => provider}) do
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
  Register a new user from external OAuth provider.
  """
  @spec callback(Plug.Conn.t(), map) :: Plug.Conn.t()
  def callback(
        %Plug.Conn{assigns: %{ueberauth_auth: %Auth{info: %Auth.Info{} = info}}} = conn,
        %{"code" => _code, "provider" => provider}
      ) do
    username = info.nickname || info.name

    case User.get_user(username, provider) do
      %User{} = user ->
        conn
        |> assign(:user, user)
        |> put_view(RDFView)
        |> render(:show, data: user.profile)

      nil ->
        case User.create_from_remote(username: username, provider: provider) do
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
end
