defmodule CPub.LDP do
  @moduledoc """
  Linked Data Platform context
  """

  alias CPub.LDP.BasicContainer

  alias CPub.Repo

  @doc """
  Creates an empty container.
  """
  def create_basic_container(opts \\ []) do
    BasicContainer.new(opts)
    |> BasicContainer.changeset()
    |> Repo.insert()
  end

  @doc """
  Gets a single BasicContainer.

  Raises `Ecto.NoResultsError` if the BasicContainer does not exist.
  """
  def get_basic_container!(id), do: Repo.get!(BasicContainer, id)

end
