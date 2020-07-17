defmodule CPub.Web.Authentication.Strategy.OIDC do
  @moduledoc """
  Meta strategy for `Ueberauth.Strategy.OIDC` that allows dynamic client configuration.
  """
  use Ueberauth.Strategy

  alias CPub.Repo

  alias CPub.Web.Authentication.OAuthClient.Client

  alias Ueberauth.Strategy.OIDC

  # Get a suitable client for the site
  defp get_client(conn, site) do
    Repo.get_one_by(Client, %{provider: to_string(strategy_name(conn)), site: site})
  end

  def handle_request!(%Plug.Conn{} = conn) do
    site = conn.params["site"]

    if is_nil(site) do
      conn
      |> set_errors!(error("oidc", "no OpenID issuer provided"))
    else
      # encode the site in the OAuth 2.0 state parameter
      state = Phoenix.Token.encrypt(conn, "ueberauth.oidc", site)

      case get_client(conn, site) do
        {:ok, client} ->
          conn
          |> Ueberauth.run_request(
            strategy_name(conn),
            {OIDC,
             [
               issuer: site,
               client_id: client.client_id,
               client_secret: client.client_secret,
               extra_request_params: %{state: state}
             ]}
          )

        _ ->
          conn
          |> set_errors!(error("oidc", "no associated client"))
      end
    end
  end

  defp replace_strategy(%Plug.Conn{assigns: %{ueberauth_auth: auth}} = conn) do
    conn
    |> assign(:ueberauth_auth, %{auth | strategy: __MODULE__})
  end

  defp replace_strategy(conn), do: conn

  def handle_callback!(%Plug.Conn{} = conn) do
    # extract the site from the state param
    with {:ok, site} <-
           Phoenix.Token.decrypt(conn, "ueberauth.oidc", conn.params["state"]),
         {:ok, client} <- get_client(conn, site) do
      conn
      |> Ueberauth.run_callback(
        strategy_name(conn),
        {OIDC,
         [
           issuer: site,
           client_id: client.client_id,
           client_secret: client.client_secret
         ]}
      )
      # act like we are not the OIDC strategy
      |> replace_strategy()
    end
  end
end
