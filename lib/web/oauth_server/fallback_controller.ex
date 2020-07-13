defmodule CPub.Web.OAuthServer.FallbackController do
  @moduledoc """
  Error handler for OAuth 2.0 Authorization Server.

  See also https://tools.ietf.org/html/rfc6749#section-4.1.2.1 and https://tools.ietf.org/html/rfc6749#section-4.2.2.1
  """

  use CPub.Web, :controller

  @doc """
  Redirect connection to redirect_uri with error code and description
  """
  def call(
        %Plug.Conn{assigns: %{redirect_uri: redirect_uri, state: state}} = conn,
        {:error, code, description}
      ) do
    cb_uri =
      redirect_uri
      |> Map.put(
        :query,
        URI.encode_query(%{
          error: code,
          error_description: description,
          state: state
        })
      )
      |> URI.to_string()

    conn
    |> redirect(external: cb_uri)
  end

  @doc """
  If redirect_uri is invalid or not present print an ugly message
  """
  def call(%Plug.Conn{} = conn, {:error, _t, msg}) do
    conn
    |> put_status(:bad_request)
    |> text(msg)
  end
end
