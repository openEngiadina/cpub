defmodule CPub.Web.Authentication.Strategy.Fediverse do
  @moduledoc """
  `Ueberauth.Strategy` for authenticating with a dynamic Mastodon/Pleroma instance.

  This is a "meta"-Strategy and uses `Uberauth.Strategy.Pleroma` for authenticating with individual instances.
  """

  use Ueberauth.Strategy

  alias CPub.Repo

  alias CPub.Web.Authentication.OAuthClient.Client

  alias Ueberauth.Auth
  alias Ueberauth.Strategy.Pleroma

  # The Mastodon API for dynamically creating clients (see https://docs.joinmastodon.org/methods/apps/)
  @register_client_endpoint "/api/v1/apps"

  # TODO this should idenitfy the instance
  @default_client_name "CPub"

  @doc """
  Create a client by using the apps endpoint
  """
  defp create_client(conn, site) do
    url =
      URI.merge(site, @register_client_endpoint)
      |> URI.to_string()

    headers = [{"Content-Type", "application/json"}]

    body =
      Jason.encode!(%{
        client_name: @default_client_name,
        # TODO: I can't get this to work with read:accounts
        scopes: "read",
        redirect_uris: callback_url(conn)
      })

    with {:ok, _, _, client_ref} <- :hackney.request(:post, url, headers, body, []),
         {:ok, body} <- :hackney.body(client_ref),
         {:ok, client_attrs} <- Jason.decode(body) do
      Client.create(%{
        site: site,
        provider: to_string(strategy_name(conn)),
        client_id: client_attrs["client_id"],
        client_secret: client_attrs["client_secret"]
      })
    end
  end

  @doc """
  Get a suitable client for the site
  """
  defp get_client(conn, site) do
    case Repo.get_one_by(Client, %{provider: to_string(strategy_name(conn)), site: site}) do
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
      |> set_errors!(error("fediverse", "no site given"))
    else
      # encode the site in the OAuth 2.0 state parameter
      state = Phoenix.Token.encrypt(conn, "ueberauth.fediverse", site)

      with {:ok, client} <- get_client(conn, site) do
        conn
        |> Ueberauth.run_request(
          strategy_name(conn),
          {Pleroma,
           [
             site: site,
             client_id: client.client_id,
             client_secret: client.client_secret,
             oauth_request_params: %{state: state}
           ]}
        )
      else
        err ->
          conn
          |> set_errors!(error("fediverse", "failed to create client"))
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
           Phoenix.Token.decrypt(conn, "ueberauth.fediverse", conn.params["state"]),
         {:ok, client} <- get_client(conn, site) do
      conn
      |> Ueberauth.run_callback(
        strategy_name(conn),
        {Pleroma,
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
