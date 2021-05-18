# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.ERIS do
  @moduledoc """
  ERIS bindings to mnesia database.
  """

  alias CPub.DB

  alias RDF.FragmentGraph

  defmodule Block do
    @moduledoc """
    An encrypted block.
    """

    use Memento.Table,
      attributes: [:ref, :data],
      type: :set
  end

  defmodule Transaction do
    @moduledoc """
    A mnesia transaction that is created when encoding/decoding ERIS content.
    """

    defstruct []

    @doc """
    Returns a new transaction.
    """
    def new, do: %Transaction{}

    defimpl ERIS.BlockStorage, for: __MODULE__ do
      def put(transaction, data) do
        ref = ERIS.Crypto.blake2b(data)
        _ = Memento.Query.write(%Block{ref: ref, data: data})

        {:ok, transaction}
      end

      def get(_, ref) do
        case Memento.Query.read(Block, ref) do
          %Block{data: data} ->
            {:ok, data}

          nil ->
            {:error, :eris_block_not_found}
        end
      end

      def delete(transaction, data) do
        ref = ERIS.Crypto.blake2b(data)
        _ = Memento.Query.delete_record(%Block{ref: ref, data: data})

        {:ok, transaction}
      end
    end
  end

  @doc """
  Encode some data using ERIS and persist block to database.any()
  """
  @spec put(FragmentGraph.t() | String.t()) :: {:ok, ERIS.ReadCapability.t()}
  def put(%FragmentGraph{} = fg) do
    fg
    |> FragmentGraph.CSexp.encode()
    |> put()
  end

  def put(data) when is_binary(data) do
    DB.transaction(fn ->
      transaction = Transaction.new()

      with {read_capability, _} <- ERIS.encode(data, transaction), do: read_capability
    end)
  end

  @doc """
  Delete ERIS-encoded data blocks from database.any()
  """
  @spec delete(FragmentGraph.t() | String.t()) :: {:ok, nil}
  def delete(%FragmentGraph{} = fg) do
    fg
    |> FragmentGraph.CSexp.encode()
    |> delete()
  end

  def delete(data) when is_binary(data) do
    DB.transaction(fn ->
      transaction = Transaction.new()

      with {:ok, _} <- ERIS.delete(data, transaction), do: nil
    end)
  end

  @doc """
  Decode ERIS encoded content given a read capability.
  """
  @spec get(ERIS.ReadCapability.t()) :: {:ok, {:ok, String.t()}}
  def get(read_capability) do
    DB.transaction(fn ->
      transaction = Transaction.new()

      ERIS.decode(read_capability, transaction)
    end)
  end

  @spec get_rdf(String.t() | ERIS.ReadCapability.t()) ::
          :ok | {:ok, FragmentGraph.t()} | {:error, any}
  def get_rdf(urn) when is_binary(urn) do
    with {:ok, read_capability} <- ERIS.ReadCapability.parse(urn) do
      get_rdf(read_capability)
    end
  end

  def get_rdf(%ERIS.ReadCapability{} = read_capability) do
    DB.transaction(fn ->
      transaction = Transaction.new()

      case ERIS.decode(read_capability, transaction) do
        {:ok, data} ->
          FragmentGraph.CSexp.decode(data, ERIS.ReadCapability.to_string(read_capability))

        error ->
          DB.abort(error)
      end
    end)
  end
end
