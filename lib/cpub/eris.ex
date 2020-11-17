defmodule CPub.ERIS do
  @moduledoc """
  ERIS bindings to mnesia database.
  """

  alias CPub.DB

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

    defimpl ERIS.BlockStorage, for: __MODULE__ do
      def put(transaction, data) do
        ref = ERIS.Crypto.blake2b(data)
        Memento.Query.write(%Block{ref: ref, data: data})
        {:ok, transaction}
      end

      def get(_, ref) do
        case Memento.Query.read(Block, ref) do
          nil ->
            {:error, :eris_block_not_found}

          %Block{data: data} ->
            {:ok, data}
        end
      end
    end
  end

  @doc """
  Encode some data using ERIS and persist block to database.any()
  """
  def put(%RDF.FragmentGraph{} = fg) do
    fg
    |> RDF.FragmentGraph.CSexp.encode()
    |> put()
  end

  def put(data) when is_binary(data) do
    DB.transaction(fn ->
      transaction = Transaction.new()

      with {read_capability, _} <- ERIS.encode(data, transaction) do
        read_capability
      end
    end)
  end

  @doc """
  Decode ERIS encoded content given a read capability.
  """
  def get(read_capability) do
    DB.transaction(fn ->
      transaction = Transaction.new()

      ERIS.decode(read_capability, transaction)
    end)
  end

  def get_rdf(read_capability) do
    DB.transaction(fn ->
      transaction = Transaction.new()

      with {:ok, data} <- ERIS.decode(read_capability, transaction) do
        data |> RDF.FragmentGraph.CSexp.decode(ERIS.ReadCapability.to_string(read_capability))
      else
        error -> DB.abort(error)
      end
    end)
  end
end
