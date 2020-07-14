defmodule CPub.Web.OAuthServer.AuthorizationPlug do
  @moduledoc """
  Plug that assigns a `CPub.Web.OAuthServer.Authorization` to the connection if valid access token is found in headers.

  Note that routes that require authorization still need to manually check if the authorization assigned in the connection by this plug is valid for the ressource being accessed.
  """

  use Phoenix.Controller, namespace: CPub.Web
  import Plug.Conn

  alias CPub.Repo
  alias CPub.Web.OAuthServer.Token

  def init(opts), do: opts

  def call(%Plug.Conn{} = conn, _opts) do
    case fetch_token_from_header(conn) do
      {:ok, access_token} ->
        with {:ok, token} <-
               Repo.get_one_by(Token, %{access_token: access_token})
               |> Repo.preload(:authorization),
             false <- Token.expired?(token) do
          conn
          |> assign(:authorization, token.authorization)
        else
          _ ->
            # If token is invalid or expired then halt the connection and display error
            conn
            |> unauthorized()
        end

      :no_token_found ->
        # If there is no token, continue without assigning authorization
        conn
    end
  end

  @doc """
  Helper to halt an unauthorized request.

  TODO Solid WebID-OIDC Authentication Spec recommends to provide among with HTTP
  401 Unauthorized response code some human-readable HTML, containing either a
  Select Provider form, or a meta-refresh redirect to a Select Provider page (https://github.com/solid/webid-oidc-spec/blob/master/example-workflow.md#1-initial-request).
  """
  @spec unauthorized(Plug.Conn.t()) :: Plug.Conn.t()
  def unauthorized(%Plug.Conn{} = conn) do
    conn
    |> put_status(:unauthorized)
    |> text("request is not authorized")
    |> halt()
  end

  # Get token from headers (code from Pleroma)

  @realm_reg Regex.compile!("Bearer\:?\s+(.*)$", "i")

  @spec fetch_token_from_header(Plug.Conn.t()) :: :no_token_found | {:ok, String.t()}
  defp fetch_token_from_header(%Plug.Conn{} = conn) do
    get_req_header(conn, "authorization")
    |> fetch_token_str()
  end

  @spec fetch_token_str(Keyword.t()) :: :no_token_found | {:ok, String.t()}
  defp fetch_token_str([]), do: :no_token_found

  defp fetch_token_str([token | tail]) do
    trimmed_token = String.trim(token)

    case Regex.run(@realm_reg, trimmed_token) do
      [_, match] -> {:ok, String.trim(match)}
      _ -> fetch_token_str(tail)
    end
  end
end
