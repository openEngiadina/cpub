defmodule CPub.ERIS do
  @moduledoc """
  ERIS bindings to mnesia database.
  """

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
    def new() do
      %Transaction{}
    end

    # TODO: do this in a single transaction
    defimpl ERIS.BlockStorage, for: __MODULE__ do
      def put(transaction, data) do
        ref = ERIS.Crypto.blake2b(data)

        with {:ok, _} <-
               Memento.transaction(fn ->
                 Memento.Query.write(%Block{ref: ref, data: data})
               end) do
          {:ok, transaction}
        end
      end

      def get(_, ref) do
        Memento.transaction(fn ->
          case Memento.Query.read(Block, ref) do
            nil ->
              {:error, :not_found}

            %Block{data: data} ->
              data
          end
        end)
      end
    end
  end

  @doc """
  Encode some data using ERIS and persist block to database.any()
  """
  def put(data) do
    transaction = Transaction.new()

    with {read_capability, _} <- ERIS.encode(data, transaction) do
      {:ok, read_capability}
    end
  end

  @doc """
  Decode ERIS encoded content given a read capability.
  """
  def decode(read_capability) do
    transaction = Transaction.new()

    ERIS.decode(read_capability, transaction)
  end
end
