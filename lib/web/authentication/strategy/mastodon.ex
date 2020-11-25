defmodule CPub.Web.Authentication.Strategy.Mastodon do
  @moduledoc """
  `Ueberauth.Strategy` for authenticating with a dynamic Mastodon/Pleroma
  instance.

  This is a "meta"-Strategy and uses
  `CPub.Web.Authentication.Strategy.Mastodon.Instance` for authenticating with
  individual instances.
  """

  use Ueberauth.Strategy

  alias CPub.Web.Authentication.OAuthClient
  alias CPub.Web.Authentication.Strategy.Mastodon.Instance

  # The Mastodon API for dynamically creating clients (see https://docs.joinmastodon.org/methods/apps/)
  @register_client_endpoint "/api/v1/apps"

  # TODO this should idenitfy the instance
  @default_client_name "CPub"

  # Create a client by using the apps endpoint
  defp create_client(conn, site) do
    url =
      URI.merge(site, @register_client_endpoint)
      |> URI.to_string()

    headers = [{"Content-Type", "application/json"}]

    body =
      Jason.encode!(%{
        client_name: @default_client_name,
        scopes: "read:accounts",
        redirect_uris: callback_url(conn)
      })

    with {:ok, _, _, client_ref} <- :hackney.request(:post, url, headers, body, []),
         {:ok, body} <- :hackney.body(client_ref),
         {:ok, client_attrs} <- Jason.decode(body) do
      OAuthClient.create(%{
        site: site,
        provider: :mastodon,
        client_id: client_attrs["client_id"],
        client_secret: client_attrs["client_secret"]
      })
    end
  end

  # Get or create a suitable client for the site.
  defp get_client(conn, site) do
    case OAuthClient.get(site) do
      {:ok, client} ->
        {:ok, client}

      _ ->
        create_client(conn, site)
    end
  end

  def handle_request!(%Plug.Conn{} = conn) do
    site = conn.params["site"]

    if is_nil(site) do
      conn
      |> set_errors!(error("mastodon_no_site_given", "no site given"))
    else
      # encode the site in the OAuth 2.0 state parameter
      state = Phoenix.Token.encrypt(conn, "ueberauth.mastodon", site)

      case get_client(conn, site) do
        {:ok, client} ->
          conn
          |> Ueberauth.run_request(
            strategy_name(conn),
            {Instance,
             [
               site: site,
               client_id: client.client_id,
               client_secret: client.client_secret,
               oauth_request_params: %{state: state, scope: "read:accounts"}
             ]}
          )

        _ ->
          conn
          |> set_errors!(error("mastodon_no_client", "failed to create client"))
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
           Phoenix.Token.decrypt(conn, "ueberauth.mastodon", conn.params["state"]),
         {:ok, client} <- get_client(conn, site) do
      conn
      |> Ueberauth.run_callback(
        strategy_name(conn),
        {Instance,
         [
           site: site,
           client_id: client.client_id,
           client_secret: client.client_secret,
           oauth_request_params: %{}
         ]}
      )
      # act like we are not the Pleroma strategy
      |> replace_strategy()
    end
  end
end
