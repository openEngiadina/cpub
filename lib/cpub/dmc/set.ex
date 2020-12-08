# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.DMC.Set do
  @moduledoc """
  Distributed Mutable Container - Set
  """

  alias CPub.DMC

  alias RDF.FragmentGraph

  require Qlc
  alias :mnesia, as: Mnesia

  defmodule Add do
    @moduledoc """
    An mnesia index of DMC Set Add operation.
    """
    use Memento.Table,
      attributes: [:id, :container, :value],
      index: [:container],
      type: :set

    def insert!(fg, container, value) do
      CPub.DB.transaction(fn ->
        case CPub.ERIS.put(fg) do
          {:ok, read_capability} ->
            %__MODULE__{
              id: read_capability,
              container: container,
              value: value
            }
            |> CPub.DB.write()
        end
      end)
    end

    @doc """
    Insert an `Add` operation into the index.
    """
    def insert(%FragmentGraph{} = fg) do
      add_type = RDF.IRI.new(DMC.NS.Add)

      with description <- fg[:base_subject],
           [^add_type] <- description[RDF.type()],
           [%RDF.IRI{} = container_iri] <- description[DMC.NS.container()],
           {:ok, container} <- DMC.Identifier.parse(container_iri),
           [%RDF.IRI{} = value] <- description[RDF.value()],
           {:ok, value_read_capability} <- ERIS.ReadCapability.parse(RDF.IRI.to_string(value)) do
        insert!(fg, container, value_read_capability)
      else
        {:error, _} = err ->
          err

        _ ->
          {:error, :invalid_dmc_operation}
      end
    end

    @doc """
    Create and insert a new Add operation.
    """
    def new(id, %ERIS.ReadCapability{} = value) do
      with {:ok, id} <- DMC.Identifier.parse(id) do
        FragmentGraph.new()
        |> FragmentGraph.add(RDF.type(), DMC.NS.Add)
        |> FragmentGraph.add(RDF.value(), ERIS.ReadCapability.to_string(value) |> RDF.iri())
        |> FragmentGraph.add(DMC.NS.container(), DMC.Identifier.to_iri(id))
        |> insert()
      end
    end

    def new(id, value) do
      with {:ok, read_capability} <- ERIS.ReadCapability.parse(value) do
        new(id, read_capability)
      end
    end
  end

  defmodule Remove do
    @moduledoc """
    Mnesia index for Remove operations.
    """

    use Memento.Table,
      attributes: [:id, :container, :operation],
      index: [:container],
      type: :set

    def insert!(fg, container, operation) do
      CPub.DB.transaction(fn ->
        case CPub.ERIS.put(fg) do
          {:ok, read_capability} ->
            %__MODULE__{
              id: read_capability,
              container: container,
              operation: operation
            }
            |> CPub.DB.write()
        end
      end)
    end

    @doc """
    Insert an `Remove` operation into the index.
    """
    def insert(%FragmentGraph{} = fg) do
      remove_type = RDF.IRI.new(DMC.NS.Remove)

      with description <- fg[:base_subject],
           [^remove_type] <- description[RDF.type()],
           [%RDF.IRI{} = container_iri] <- description[DMC.NS.container()],
           {:ok, container} <- DMC.Identifier.parse(container_iri),
           [%RDF.IRI{} = operation_iri] <- description[DMC.NS.operation()],
           {:ok, operation} <- ERIS.ReadCapability.parse(RDF.IRI.to_string(operation_iri)) do
        insert!(fg, container, operation)
      else
        {:error, _} = err ->
          err

        _ ->
          {:error, :invalid_dmc_operation}
      end
    end

    @doc """
    Create and insert a new Remove operation.
    """
    def new(id, operation) do
      with {:ok, id} <- DMC.Identifier.parse(id),
           {:ok, operation} <- ERIS.ReadCapability.parse(operation) do
        FragmentGraph.new()
        |> FragmentGraph.add(RDF.type(), DMC.NS.Remove)
        |> FragmentGraph.add(DMC.NS.container(), DMC.Identifier.to_iri(id))
        |> FragmentGraph.add(
          DMC.NS.operation(),
          operation |> ERIS.ReadCapability.to_string() |> RDF.iri()
        )
        |> insert()
      end
    end
  end

  defp removed_ops(container_id, root_public_key) do
    Qlc.fold(
      Qlc.q(
        "[ROperation || {_, RId, RContainer, ROperation} <- Remove, RContainer == Container, {_,_,SPublicKey, SMessage} <- Signature, SMessage == RId, SPublicKey == RootPublicKey]",
        Remove: Mnesia.table(Remove),
        Container: container_id,
        RootPublicKey: root_public_key,
        Signature: Mnesia.table(CPub.Signify.Signature)
      ),
      MapSet.new(),
      fn op, ops ->
        MapSet.put(ops, op)
      end
    )
  end

  defp add_ops_handle(id, root_public_key) do
    Qlc.q(
      "[{AId, Value} || {_, AId, AContainer, Value} <- Add, AContainer == Container, {_,_,SPublicKey, SMessage} <- Signature, SMessage == AId, SPublicKey == RootPublicKey]",
      Add: Mnesia.table(Add),
      Signature: Mnesia.table(CPub.Signify.Signature),
      Container: id,
      RootPublicKey: root_public_key,
      Signature: Mnesia.table(CPub.Signify.Signature)
    )
  end

  @doc """
  Return the current state of the DMC Set as a `MapSet`.
  """
  def state(dmc_identifier) do
    CPub.DB.transaction(fn ->
      with {:ok, %{id: id, root_public_key: root_public_key}} <-
             DMC.Definition.get(dmc_identifier),
           removed_ops <- removed_ops(id, root_public_key),
           adds <- add_ops_handle(id, root_public_key) do
        Qlc.fold(adds, MapSet.new(), fn {add_op, value}, state ->
          if MapSet.member?(removed_ops, add_op) do
            state
          else
            MapSet.put(state, value)
          end
        end)
      end
    end)
  end

  @doc """
  Returns a new DMC set definition for the given public key.
  """
  def new(%CPub.Signify.PublicKey{} = public_key) do
    with {:ok, read_capability} <-
           FragmentGraph.new()
           |> FragmentGraph.add(RDF.type(), DMC.NS.SetDefinition)
           |> FragmentGraph.add(
             DMC.NS.rootPublicKey(),
             CPub.Signify.PublicKey.to_iri(public_key)
           )
           |> FragmentGraph.finalize()
           |> CPub.ERIS.put() do
      {:ok, %{id: read_capability, root_public_key: public_key}}
    end
  end
end
