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
      |> render("show.json", client: client)
    end
  end

  def show(%Plug.Conn{} = conn, %{"id" => id}) do
    with {:ok, client} <- Repo.get_one(Client, id) do
      conn
      |> render("show.json", client: client)
    end
  end

  #   @spec verify(Plug.Conn.t(), map) :: Plug.Conn.t()
  #   def verify(%Plug.Conn{assigns: %{user: _user, token: token}} = conn, _params) do
  #     with %Token{app: %App{} = app} <- Repo.preload(token, :app) do
  #       render(conn, "show.json", app: app)
  #     end
  #   end
end
