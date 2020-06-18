defmodule CPub.Web.EnsureAuthenticationPlug do
  @moduledoc """
  Plug to ensure that connections is authenticated with a `CPub.User`.
  """

  import Plug.Conn

  alias CPub.{Config, User}
  alias CPub.Web.Router.Helpers, as: Routes

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(%Plug.Conn{assigns: %{user: %User{}}} = conn, _opts), do: conn
  def call(%Plug.Conn{} = conn, _opts), do: unauthorized(conn)

  @doc """
  Solid WebID-OIDC Authentication Spec recommends to provide among with HTTP
  401 Unauthorized response code some human-readable HTML, containing either a
  Select Provider form, or a meta-refresh redirect to a Select Provider page.
  https://github.com/solid/webid-oidc-spec/blob/master/example-workflow.md#1-initial-request
  """
  @spec unauthorized(Plug.Conn.t()) :: Plug.Conn.t()
  def unauthorized(%Plug.Conn{} = conn) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(:unauthorized, meta_refresh_redirect_html(conn))
    |> halt()
  end

  @spec meta_refresh_redirect_html(Plug.Conn.t()) :: String.t()
  defp meta_refresh_redirect_html(%Plug.Conn{} = conn) do
    """
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <meta http-equiv="refresh" content="1; URL='@redirect_uri'" />
        <title>@title</title>
      </head>
      <body>Unauthorized. Redirecting to Authentication page...</body>
    </html>
    """
    |> String.replace("@title", Config.instance()[:name])
    |> String.replace("@redirect_uri", Routes.o_auth_path(conn, :authorize))
  end
end
