defmodule CPub.Web.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """

  use CPub.Web, :controller

  alias CPub.Web.ChangesetView

  @type error_tuple ::
          {:error, Ecto.Changeset.t() | String.Chars.t() | atom}
          | {:error, any, Ecto.Changeset.t(), any}

  @spec call(Plug.Conn.t(), error_tuple) :: Plug.Conn.t()
  def call(%Plug.Conn{} = conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  # Handles error response from an Repo.transaction
  def call(%Plug.Conn{} = conn, {:error, _, %Ecto.Changeset{} = changeset, _}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(%Plug.Conn{} = conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> text("Not found")
  end

  def call(%Plug.Conn{} = conn, {:error, "Invalid argument; Not a valid UUID: " <> _ = msg}) do
    conn
    |> put_status(400)
    |> text(msg)
  end

  def call(%Plug.Conn{} = conn, {:error, msg}) do
    conn
    |> put_status(500)
    |> text(msg)
  end

  # This catches Ecto.Multi errors
  def call(%Plug.Conn{} = conn, {:error, _, msg, _}) do
    conn
    |> put_status(500)
    |> text(msg)
  end
end
