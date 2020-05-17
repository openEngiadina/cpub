defmodule CPub.Web.OAuthAuthenticationPlug do
  @moduledoc """
  Plug for OAuth authentication.
  """

  import Ecto.Query
  import Plug.Conn

  alias CPub.{Config, Repo, User}
  alias CPub.Web.OAuth.{App, Token}

  @authorization_header "authorization"
  @bearer_token_regex Regex.compile!("Bearer\:?\s+(.*)$", "i")

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(%Plug.Conn{assigns: %{user: %User{}}} = conn, _opts), do: conn

  def call(%Plug.Conn{params: %{"access_token" => access_token}} = conn, _opts) do
    conn
    |> fetch_cookies(signed: [Config.cookie_name()])
    |> do_assign_token(access_token)
  end

  def call(%Plug.Conn{} = conn, _opts) do
    case fetch_access_token(conn) do
      nil -> conn
      access_token -> do_assign_token(conn, access_token)
    end
  end

  @spec do_assign_token(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  defp do_assign_token(%Plug.Conn{} = conn, access_token) do
    case fetch_token_with_user(access_token) do
      {token, user} ->
        conn
        |> assign(:token, token)
        |> assign(:user, user)

      _ ->
        case fetch_token_with_app(access_token) do
          {token, app} ->
            conn
            |> assign(:token, token)
            |> assign(:app, app)

          _ ->
            conn
        end
    end
  end

  @spec fetch_token_with_user(String.t()) :: {Token.t(), User.t()} | nil
  defp fetch_token_with_user(access_token) do
    query =
      from(t in Token,
        where: t.access_token == ^access_token and t.valid_until > ^NaiveDateTime.utc_now(),
        join: user in assoc(t, :user),
        preload: [user: user]
      )

    with %Token{user: user} = token <- Repo.one(query), do: {token, user}
  end

  @spec fetch_token_with_app(String.t()) :: {Token.t(), App.t()} | nil
  defp fetch_token_with_app(access_token) do
    query =
      from(t in Token,
        where: t.access_token == ^access_token and t.valid_until > ^NaiveDateTime.utc_now(),
        join: app in assoc(t, :app),
        preload: [app: app]
      )

    with %Token{app: app} = token <- Repo.one(query), do: {token, app}
  end

  @spec fetch_access_token(Plug.Conn.t()) :: String.t() | nil
  defp fetch_access_token(%Plug.Conn{} = conn) do
    headers = get_req_header(conn, @authorization_header)

    case fetch_access_token_from_headers(headers) do
      nil -> fetch_access_token_from_session(conn)
      access_token -> access_token
    end
  end

  @spec fetch_access_token_from_headers(keyword) :: String.t() | nil
  defp fetch_access_token_from_headers([]), do: nil

  defp fetch_access_token_from_headers([header | rest]) do
    case Regex.run(@bearer_token_regex, String.trim(header)) do
      [_, access_token] -> String.trim(access_token)
      _ -> fetch_access_token_from_headers(rest)
    end
  end

  @spec fetch_access_token_from_session(Plug.Conn.t()) :: String.t() | nil
  defp fetch_access_token_from_session(%Plug.Conn{} = conn) do
    case get_session(conn, :oauth_access_token) do
      nil -> nil
      access_token -> access_token
    end
  end
end
