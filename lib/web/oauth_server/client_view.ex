defmodule CPub.Web.OAuthServer.ClientView do
  @moduledoc """
  View for `CPub.Web.OAuthServer.Client`.
  """

  use CPub.Web, :view

  alias CPub.Web.OAuthServer.Client

  @spec render(String.t(), map) :: map
  def render("show.json", %{client: %Client{} = client}) do
    %{
      client_name: client.client_name,
      client_id: client.client_id,
      client_secret: client.client_secret,
      redirect_uris: client.redirect_uris
    }
  end
end
