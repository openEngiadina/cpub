defmodule CPub.Web.Authorization.Utils do
  @moduledoc """
  Helpers and utils for dealing with OAuth 2.0 Endpoint requests.
  """

  alias CPub.Web.Authorization.Client
  alias CPub.Web.Authorization.Scope

  @doc """
  Returns the `CPub.Web.Authorization.Client` associated with the connection.
  """
  def get_client(%Plug.Conn{} = conn) do
    case Client.get(conn.params["client_id"]) do
      {:ok, client} ->
        {:ok, client}

      {:error, _} ->
        {:error, :invalid_request, "invalid client_id"}
    end
  end

  @doc """
  Returns a valid redirect_uri for given connection and client/authorization.
  """
  def get_redirect_uri(%Plug.Conn{} = conn, %Client{} = client) do
    case Client.get_redirect_uri(client, conn.params) do
      {:ok, redirect_uri} ->
        {:ok, redirect_uri}

      :error ->
        {:error, :invalid_request, "redirect_uri not valid or not allowed for client."}
    end
  end

  @doc """
  Returns a valid scope for given connection and client
  """
  def get_scope(%Plug.Conn{} = conn, %Client{} = client) do
    with {:ok, scope} <- Scope.parse(Access.get(conn.params, "scope", Scope.default())),
         true <- Scope.scope_subset?(scope, client.scope) do
      {:ok, scope}
    else
      _ ->
        {:error, :invalid_request, "scope not valid or not allowed for client."}
    end
  end

  @doc """
  Returns OAuth 2.0 request state from connection
  """
  def get_state(%Plug.Conn{} = conn) do
    {:ok, conn.params["state"]}
  end
end
