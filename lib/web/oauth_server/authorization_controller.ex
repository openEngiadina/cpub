defmodule CPub.Web.OAuthServer.AuthorizationController do
  @moduledoc """
  Implements functionality for CPub to act as OAuth 2.0 Authorization Server.
  """
  use CPub.Web, :controller

  action_fallback CPub.Web.OAuthServer.FallbackController

  alias CPub.Repo

  alias CPub.Web.OAuthServer.Authorization
  alias CPub.Web.OAuthServer.Client
  alias CPub.Web.OAuthServer.FallbackController

  plug :fetch_flash

  defp assign_client(%Plug.Conn{} = conn, _opts) do
    case Repo.get_one_by(Client, %{client_id: conn.params["client_id"]}) do
      {:ok, client} ->
        conn
        |> assign(:client, client)

      {:error, _} ->
        conn
        |> halt()
        |> FallbackController.call({:error, :invalid_request, "invalid client_id"})
    end
  end

  defp assing_redirect_uri(%Plug.Conn{assigns: %{client: client}} = conn, _opts) do
    case Client.get_redirect_uri(client, conn.params) do
      {:ok, redirect_uri} ->
        conn |> assign(:redirect_uri, redirect_uri)

      :error ->
        conn
        |> halt()
        |> FallbackController.call({
          :error,
          :invalid_request,
          "redirect_uri not valid or not allowed for client."
        })
    end
  end

  defp assign_state(%Plug.Conn{} = conn, _opts) do
    conn
    |> assign(:state, conn.params["state"])
  end

  defp assign_scope(%Plug.Conn{assigns: %{client: client}} = conn, _opts) do
    case Client.get_scope(client, conn.params) do
      {:ok, scope} ->
        conn |> assign(:scope, scope)

      :error ->
        conn
        |> halt()
        |> FallbackController.call({
          :error,
          :invalid_request,
          "scope not valid or not allowed for client."
        })
    end
  end

  defp assign_response_type(%Plug.Conn{} = conn, _opts) do
    case Map.get(conn.params, "response_type", "none") do
      "code" ->
        conn
        |> assign(:response_type, :code)

      # "token" ->
      #   conn
      #   |> assign(:response_type, :token)

      # "password" ->
      #   conn
      #   |> assign(:response_type, :password)

      # "client_credentials" ->
      #   conn
      #   |> assign(:response_type, :client_credentials)
      #
      # "refresh_token" ->
      #   conn
      #   |> assign(:response_type, :refresh_token)

      _ ->
        conn
        |> halt()
        |> FallbackController.call(
          {:error, :unsupported_response_type, "grant type not supported."}
        )
    end
  end

  plug :assign_client
  plug :assing_redirect_uri
  plug :assign_scope
  plug :assign_state
  plug :assign_response_type

  @doc """
  This implments the OAuth 2.0 Authorization Endpoint (https://tools.ietf.org/html/rfc6749#section-3.1)
  """
  # Authorization Code Grant (https://tools.ietf.org/html/rfc6749#section-4.1)
  def authorize(
        %Plug.Conn{
          method: "GET",
          assigns: %{
            client: client,
            session: session,
            redirect_uri: redirect_uri,
            scope: scope,
            state: state,
            response_type: :code
          }
        } = conn,
        params
      ) do
    with session <- session |> Repo.preload(:user) do
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
            client: client,
            session: session,
            response_type: :code,
            redirect_uri: redirect_uri,
            scope: scope,
            state: state
          }
        } = conn,
        %{"request_accepted" => _params}
      ) do
    with session <- session |> Repo.preload(:user),
         {:ok, authorization} <-
           Authorization.create(%{user: session.user, client: client, scope: scope}) do
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
          assigns: %{
            response_type: :code,
            redirect_uri: _redirect_uri
          }
        } = _conn,
        %{"request_denied" => _params}
      ) do
    {:error, :access_denied, "access denied"}
  end

  # If there is no session redirect user to login
  def authorize(
        %Plug.Conn{method: "GET"} = conn,
        params
      ) do
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
