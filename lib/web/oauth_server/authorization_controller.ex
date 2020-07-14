defmodule CPub.Web.OAuthServer.AuthorizationController do
  @moduledoc """
  Implements the OAuth 2.0 Authorization Endpoint (https://tools.ietf.org/html/rfc6749#section-3.1).
  """
  use CPub.Web, :controller

  action_fallback CPub.Web.OAuthServer.FallbackController

  import CPub.Web.OAuthServer.Utils

  alias CPub.Repo
  alias CPub.Web.OAuthServer.Authorization
  alias CPub.Web.OAuthServer.FallbackController

  plug :fetch_flash

  defp set_oauth_redirect_on_error(%Plug.Conn{} = conn, _opts),
    do: assign(conn, :oauth_redirect_on_error, true)

  # allow `FallbackController` to redirect to redirect_uri with error
  plug :set_oauth_redirect_on_error

  defp assign_response_type(%Plug.Conn{} = conn, _opts) do
    case Map.get(conn.params, "response_type") do
      "code" ->
        conn
        |> assign(:response_type, :code)

      # "token" ->
      #   conn
      #   |> assign(:response_type, :token)

      # "password" ->
      #   conn
      #   |> assign(:response_type, :password)

      _ ->
        conn
        |> halt()
        |> FallbackController.call(
          {:error, :unsupported_response_type, "grant type not supported."}
        )
    end
  end

  plug :assign_response_type

  # Authorization Code Grant (https://tools.ietf.org/html/rfc6749#section-4.1)
  def authorize(
        %Plug.Conn{
          method: "GET",
          assigns: %{
            session: session,
            response_type: :code
          }
        } = conn,
        params
      ) do
    with session <- session |> Repo.preload(:user),
         {:ok, client} <- get_client(conn),
         {:ok, redirect_uri} <-
           get_redirect_uri(fetch_query_params(conn), client),
         {:ok, scope} <- get_scope(conn, client),
         {:ok, state} <- get_state(conn) do
      conn
      |> render("authorize.html", %{
        client: client,
        oauth_params: %{
          client_id: client.client_id,
          response_type: :code,
          redirect_uri: redirect_uri |> URI.to_string(),
          scope: scope,
          state: state
        },
        user: session.user
      })
    end
  end

  # request accepted
  def authorize(
        %Plug.Conn{
          method: "POST",
          assigns: %{
            session: session,
            response_type: :code
          }
        } = conn,
        %{"request_accepted" => _params}
      ) do
    with session <- session |> Repo.preload(:user),
         {:ok, client} <- get_client(conn),
         {:ok, redirect_uri} <- get_redirect_uri(conn, client),
         {:ok, scope} <- get_scope(conn, client),
         {:ok, state} <- get_state(conn),
         {:ok, authorization} <-
           Authorization.create(%{
             user: session.user,
             client: client,
             scope: scope,
             redirect_uri: redirect_uri |> URI.to_string()
           }) do
      cb_uri =
        redirect_uri
        |> Map.put(
          :query,
          URI.encode_query(%{
            code: authorization.code,
            state: state
          })
        )
        |> URI.to_string()

      conn
      |> redirect(external: cb_uri)
    end
  end

  # request denied
  def authorize(
        %Plug.Conn{
          method: "POST",
          assigns: %{response_type: :code}
        } = _conn,
        %{"request_denied" => _params}
      ) do
    {:error, :access_denied, "access denied"}
  end

  # If there is no session redirect user to login
  def authorize(
        %Plug.Conn{method: "GET"} = conn,
        _params
      ) do
    # get and validate all required field so that user is not sent to login if request is invalid in first place
    with {:ok, client} <- get_client(conn),
         {:ok, _redirect_uri} <-
           get_redirect_uri(fetch_query_params(conn), client),
         {:ok, _scope} <- get_scope(conn, client),
         {:ok, _state} <- get_state(conn) do
      conn
      |> redirect(
        to:
          Routes.authentication__path(conn, :login, %{
            "on_success" =>
              Routes.oauth_server_authorization_path(conn, :authorize, conn.query_params)
          })
      )
    end
  end
end
