defmodule CPub.Database do
  @moduledoc """
  Helpers to access Database.

  Also implements a Task that is used to initialize tables.
  """

  use Task, restart: :transient

  require Logger

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  @doc """
  The nodes where data is persisted.
  """
  def nodes(), do: [node()]

  def run(_arg) do
    Logger.info("Initializing mnesia database.")

    # mnesia needs to be stopped before schema can be created
    with :ok <- Memento.stop(),
         :ok <- create_schema(),
         :ok <- Memento.start(),
         :ok <- create_tables() do
      :ok
    else
      error ->
        exit(error)
    end
  end

  # Helper to create schema and gracefully continue if schema already exists
  defp create_schema() do
    case :mnesia.create_schema(nodes()) do
      :ok ->
        Logger.debug("mnesia schema created.")
        :ok

      {:error, {_, {:already_exists, _}}} ->
        Logger.debug("mnesia schema already exists.")
        :ok

      error ->
        error
    end
  end

  defp ensure_disc_only_table_exists(table) do
    case Memento.Table.create(table, disc_only_copies: nodes()) do
      :ok ->
        :ok

      {:error, {:already_exists, _}} ->
        :ok

      error ->
        error
    end
  end

  # Helper to create tables
  defp create_tables() do
    with :ok <- ensure_disc_only_table_exists(CPub.ERIS.Block) do
      :ok
    end
  end
end
