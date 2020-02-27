defmodule CPub.Web.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use CPub.Web, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(CPub.Web.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  # Handles error response from an Repo.transaction
  def call(conn, {:error, _, %Ecto.Changeset{} = changeset, _}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(CPub.Web.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(CPub.Web.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, msg}) do
    conn
    |> put_status(500)
    |> text(msg)
  end
end
