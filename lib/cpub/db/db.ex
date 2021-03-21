# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.DB do
  @moduledoc """
  Helpers to access Database.

  Also implements a Task that is used to initialize tables.
  """

  use Task, restart: :transient

  require Logger

  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  @doc """
  The nodes where data is persisted.
  """
  @spec nodes :: [node]
  def nodes, do: [node()]

  @spec run(any) :: :ok | no_return
  def run(_arg) do
    Logger.info("Initializing mnesia database.")

    # Create the DB directory
    with :ok <- File.mkdir_p!(Application.get_env(:mnesia, :dir)),
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
  @spec create_schema :: :ok | {:error, any}
  defp create_schema do
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

  @spec ensure_table_exists(module, keyword) :: :ok | {:error, any}
  defp ensure_table_exists(table, opts) do
    case Memento.Table.create(table, opts) do
      :ok ->
        :ok

      {:error, {:already_exists, _}} ->
        :ok

      error ->
        error
    end
  end

  # Helper to create tables
  @spec create_tables :: :ok | {:error, any}
  defp create_tables do
    with :ok <- ensure_table_exists(CPub.ERIS.Block, disc_only_copies: nodes()),
         # DB Set and Register
         :ok <- ensure_table_exists(CPub.DB.Set, disc_only_copies: nodes()),
         # RDF Signify
         :ok <- ensure_table_exists(CPub.Signify.Signature, disc_only_copies: nodes()),
         # User management
         :ok <- ensure_table_exists(CPub.User, disc_only_copies: nodes()),
         :ok <- ensure_table_exists(CPub.User.Registration, disc_only_copies: nodes()),
         # OAuth Clients (that use CPub as Authorization server)
         :ok <- ensure_table_exists(CPub.Web.Authorization.Client, disc_only_copies: nodes()),
         # keep auth* tables in memory and on disc
         :ok <- ensure_table_exists(CPub.Web.Authentication.Session, disc_copies: nodes()),
         :ok <- ensure_table_exists(CPub.Web.Authorization, disc_copies: nodes()),
         :ok <- ensure_table_exists(CPub.Web.Authorization.Token, disc_copies: nodes()),
         :ok <- ensure_table_exists(CPub.Web.Authentication.OAuthClient, disc_copies: nodes()),
         # temporary `RegistrationRequest` only exists in memory
         :ok <-
           ensure_table_exists(CPub.Web.Authentication.RegistrationRequest, ram_copies: nodes()) do
      :ok
    end
  end

  # Utility functions to interact with Database

  @doc """
  Run a database transaction.

  If called from within transaction the transaction will be reused.
  """
  @dialyzer {:nowarn_function, transaction: 1}
  @spec transaction(fun) :: :ok | any | {:ok, any} | {:error, any}
  def transaction(function) do
    return_value =
      if Memento.Transaction.inside?() do
        {:ok, apply(function, [])}
      else
        Memento.transaction(function)
      end

    case return_value do
      :ok ->
        :ok

      {:ok, :ok} ->
        :ok

      {:ok, _} ->
        return_value

      {:error, {:transaction_aborted, {:cpub_error, reason}}} ->
        Logger.debug("mnesia transaction aborted (#{inspect(reason)})")
        {:error, reason}

      {:error, reason} = error ->
        Logger.warn("mnesia transaction aborted due to error (#{inspect(reason)})")
        error
    end
  end

  @doc """
  Write a record to a table.
  """
  @spec write(Memento.Table.record(), Memento.Query.options()) ::
          Memento.Table.record() | no_return()
  def write(record, opts \\ []), do: Memento.Query.write(record, opts)

  @doc """
  Abort transaction with `reason`.
  """
  @spec abort({:error, atom} | atom) :: no_return
  def abort({:error, reason}) when is_atom(reason), do: abort(reason)
  def abort(reason) when is_atom(reason), do: Memento.Transaction.abort({:cpub_error, reason})

  @doc """
  Reset the entire database.

  WARNING: Use with extreme caution as this will drop all data!
  """
  @spec reset :: :ok | no_return
  def reset do
    unless Mix.env() == :test do
      Logger.warn("Resetting database.")
    end

    _ = :mnesia.stop()
    _ = :mnesia.delete_schema(nodes())
    _ = :mnesia.start()

    run([])
  end
end
