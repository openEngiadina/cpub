defmodule CPub.Web.Authorization.UserInfoController do
  @moduledoc """
  This will eventually implement the OpenID Core userinfo endpoint (see
  https://openid.net/specs/openid-connect-core-1_0.html#UserInfo).
  """

  use CPub.Web, :controller

  action_fallback CPub.Web.Authorization.FallbackController

  alias CPub.User
  alias CPub.Web.Authorization

  plug Authorization.AuthorizationPlug

  defp get_authorized_user(conn, scope: scope) do
    if scope_subset?(scope, conn.assigns.authorization.scope) do
      with authorization <- conn.assigns.authorization |> Repo.preload(:user) do
        {:ok, authorization.user}
      end
    else
      {:error, :unauthorized}
    end
  end

  def userinfo(%Plug.Conn{assigns: %{authorization: _}} = conn, _) do
    case get_authorized_user(conn, scope: [:openid]) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> put_view(JSONView)
        |> render(:show,
          data: %{
            sub: User.actor_url(user) |> RDF.IRI.to_string()
          }
        )

      _ ->
        {:error, :invalid_request, "unauthorized"}
    end
  end

  def userinfo(%Plug.Conn{} = conn, _) do
    {:error, :invalid_request, "unauthorized"}
  end
end
