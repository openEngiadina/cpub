defmodule CPub.Objects do
  @moduledoc """
  The Objects context.
  """

  import Ecto.Query, warn: false
  alias CPub.Repo

  alias CPub.Objects.Object

  def list_objects do
    Repo.all(Object)
  end

  def get_object!(id) do
    Repo.get!(Object, id)
  end

  def create_object(attrs \\ %{}) do
    %Object{}
    |> Object.changeset(attrs)
    |> Repo.insert()
  end

end
