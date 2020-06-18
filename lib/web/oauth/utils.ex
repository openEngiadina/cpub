defmodule CPub.Web.OAuth.Utils do
  @moduledoc """
  Auxiliary functions.
  """

  alias CPub.Web.BasicAuthenticationPlug
  alias CPub.Web.OAuth.{App, Scopes}

  @spec fetch_user_credentials(Plug.Conn.t()) :: {String.t() | nil, String.t() | nil}
  def fetch_user_credentials(%Plug.Conn{} = conn) do
    # Per RFC 6749, HTTP Basic is preferred to body params
    case BasicAuthenticationPlug.fetch_credentials(conn) do
      {username, password} -> {username, password}
      nil -> {conn.params["username"], conn.params["password"]}
    end
  end

  @spec fetch_app(Plug.Conn.t()) :: App.t() | nil
  def fetch_app(%Plug.Conn{} = conn) do
    conn
    |> fetch_client_credentials()
    |> fetch_client
  end

  @spec fetch_client_credentials(Plug.Conn.t()) :: {String.t() | nil, String.t() | nil}
  defp fetch_client_credentials(%Plug.Conn{} = conn) do
    # Per RFC 6749, HTTP Basic is preferred to body params
    case BasicAuthenticationPlug.fetch_credentials(conn) do
      {client_id, client_secret} -> {client_id, client_secret}
      nil -> {conn.params["client_id"], conn.params["client_secret"]}
    end
  end

  @spec fetch_client({String.t() | nil, String.t() | nil}) :: App.t() | nil
  defp fetch_client({client_id, client_secret})
       when is_binary(client_id) and is_binary(client_secret) do
    App.get_by(%{client_id: client_id, client_secret: client_secret})
  end

  defp fetch_client({_, _}), do: nil

  @spec ensure_padding(String.t()) :: String.t()
  def ensure_padding(token) do
    token
    |> URI.decode()
    |> Base.url_decode64!(padding: false)
    |> Base.url_encode64(padding: false)
  end

  @spec validate_scopes(App.t(), map) :: {:ok, [String.t()]} | {:error, atom}
  def validate_scopes(%App{} = app, params) do
    params
    |> Scopes.fetch_scopes(app.scopes)
    |> Scopes.validate(app.scopes)
  end

  @spec append_uri_params(String.t(), map) :: String.t()
  def append_uri_params(uri, appended_params) do
    uri = URI.parse(uri)

    params =
      (uri.query || "")
      |> URI.decode_query()
      |> Map.merge(appended_params)

    uri
    |> Map.put(:query, URI.encode_query(params))
    |> URI.to_string()
  end
end
