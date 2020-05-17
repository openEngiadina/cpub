defmodule CPub.Web.OAuth.AppController do
  use CPub.Web, :controller

  alias CPub.Repo
  alias CPub.Web.OAuth.{App, Scopes, Token}

  action_fallback CPub.Web.FallbackController

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(%{body_params: params} = conn, _params) do
    scopes = Scopes.fetch_scopes(params, ["read"])

    app_attrs =
      params
      |> Map.take(["client_name", "redirect_uris", "website"])
      |> Map.put("scopes", scopes)

    with app_changeset <- App.create_changeset(%App{}, app_attrs),
         {:ok, app} <- App.create(app_changeset) do
      render(conn, "show.json", app: app)
    end
  end

  @spec verify(Plug.Conn.t(), map) :: Plug.Conn.t()
  def verify(%{assigns: %{user: _user, token: token}} = conn, _params) do
    with %Token{app: %App{} = app} <- Repo.preload(token, :app) do
      render(conn, "show.json", app: app)
    end
  end
end
