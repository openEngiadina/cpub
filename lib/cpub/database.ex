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

    # Create the DB directory
    with :ok = File.mkdir_p!(Application.get_env(:mnesia, :dir)),
         # mnesia needs to be stopped before schema can be created
         :ok <- Memento.stop(),
         # Ensure the schema is created.
         :ok <- create_schema(),
         # Restart mnesia.
         :ok <- Memento.start(),
         # Ensure tables are created.
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
    with :ok <- ensure_disc_only_table_exists(CPub.ERIS.Block),
         :ok <- ensure_disc_only_table_exists(CPub.User) do
      :ok
    end
  end

  # Utility functions to interact with Database

  alias Memento.{Query, Transaction}

  @doc """
  Run a database transaction.

  If called from within transaction the transaction will be reused.
  """
  @spec transaction(fun) :: {:ok, any} | {:error, any}
  def transaction(function) do
    return_value =
      if Memento.Transaction.inside?() do
        {:ok, apply(function, [])}
      else
        Memento.transaction(function)
      end

    case return_value do
      {:ok, _} ->
        return_value

      {:error, {:transaction_aborted, {:cpub_error, reason}}} ->
        Logger.debug("mnesia transaction aborted.", error: reason)
        {:error, reason}

      _ ->
        Logger.warn("mnesia transaction aborted", error: return_value)
        return_value
    end
  end

  @doc """
  Abort transaction with `reason`.
  """
  def abort({:error, reason}), do: abort(reason)
  def abort(reason), do: Memento.Transaction.abort({:cpub_error, reason})

  @doc """
  Reset the entire database.

  WARNING: Use with extreme caution as this will drop all data!
  """
  def reset() do
    Logger.warn("Resetting database.")
    :mnesia.stop()
    :mnesia.delete_schema(nodes())
    :mnesia.start()
    run([])
  end
end
