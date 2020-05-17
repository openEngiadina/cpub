defmodule CPub.Web.OAuth.AppView do
  @moduledoc """
  View for `CPub.Web.OAuth.App`.
  """

  use CPub.Web, :view

  alias CPub.Web.OAuth.App

  @spec render(String.t(), map) :: map
  def render("show.json", %{app: %App{} = app}) do
    %{
      name: app.client_name,
      client_id: app.client_id,
      client_secret: app.client_secret,
      redirect_uri: app.redirect_uris,
      website: app.website
    }
  end
end
