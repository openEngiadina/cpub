defmodule CPubWeb.Authentication.Basic do
  @moduledoc """
  Plug to handle Basic Authentication
  """
  import Plug.Conn

  use CPubWeb, :controller

  def init(options) do
    options
  end

  def call(conn, _opts) do
    case get_req_header(conn, "authentication") do

      ["Basic " <> credentials] ->
        case verify(credentials) do
          {:ok, user} ->
            assign(conn, :user, user)

          {:error, _err} ->
            conn
            |> put_status(:unauthorized)
            |> put_view(CPubWeb.ErrorView)
            |> render("401.json")
            |> halt()

        end

      _ -> conn
    end
    conn
  end

  def verify(credentials) do
    case Base.decode64(credentials) do

      {:ok, decoded_credentials} ->
        case String.split(decoded_credentials, ":", parts: 2) do
          [username, password] ->
            CPub.Users.verify_user(username, password)

          _ ->
            {:error, "can not decode credentials"}
        end

      _ ->
        {:error, "can not decode credentials"}

    end
  end

end
