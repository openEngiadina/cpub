defmodule CPub.Web.OAuthServer.ClientController do
  @moduledoc """
  Controller that handles OAuth 2.0 client registration.

  TODO implement https://openid.net/specs/openid-connect-registration-1_0.html
  """
  use CPub.Web, :controller

  alias CPub.Repo
  alias CPub.Web.OAuthServer.Client

  action_fallback CPub.Web.FallbackController

  @doc """
  Create a new OAuth 2.0 client
  """
  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(%Plug.Conn{body_params: body} = conn, _params) do
    attrs =
      body
      |> Map.take(["client_name", "redirect_uris", "scopes"])

    with {:ok, client} <- Client.create(attrs) do
      conn
      |> put_status(:created)
      |> put_view(JSONView)
      |> render(:show,
        data: %{
          client_name: client.client_name,
          client_id: client.client_id,
          client_secret: client.client_secret,
          redirect_uris: client.redirect_uris,
          scopes: client.scopes
        }
      )
    end
  end

  def show(%Plug.Conn{} = conn, %{"id" => id}) do
    with {:ok, client} <- Repo.get_one(Client, id) do
      conn
      |> put_status(:ok)
      |> put_view(JSONView)
      |> render(:show,
        data: %{
          client_name: client.client_name,
          client_id: client.client_id,
          client_secret: client.client_secret,
          redirect_uris: client.redirect_uris,
          scopes: client.scopes
        }
      )
    end
  end

  #   @spec verify(Plug.Conn.t(), map) :: Plug.Conn.t()
  #   def verify(%Plug.Conn{assigns: %{user: _user, token: token}} = conn, _params) do
  #     with %Token{app: %App{} = app} <- Repo.preload(token, :app) do
  #       render(conn, "show.json", app: app)
  #     end
  #   end
end
