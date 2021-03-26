# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.DB.Set do
  @moduledoc """
  A set in the CPub database.
  """

  alias CPub.DB

  alias Memento.Query

  use Memento.Table,
    attributes: [:id, :member],
    type: :bag

  @doc """
  Returns the identifier of a new Set.
  """
  @spec new :: RDF.IRI.t()
  def new, do: RDF.UUID.generate()

  @doc """
  Returns the Set with given id as MapSet.
  """
  @spec state(RDF.IRI.t()) :: {:ok, MapSet.t()} | {:error, any}
  def state(id) do
    DB.transaction(fn ->
      Query.select(__MODULE__, {:==, :id, id})
      |> MapSet.new(fn record -> record.member end)
    end)
  end

  @doc """
  Insert an element into set with given id.
  """
  @spec add(RDF.IRI.t(), any) :: :ok | {:error, any}
  def add(id, element) do
    DB.transaction(fn ->
      _ = DB.write(%__MODULE__{id: id, member: element})

      :ok
    end)
  end

  @doc """
  Remove an element from the set with given id.
  """
  @spec remove(RDF.IRI.t(), any) :: :ok | {:error, any}
  def remove(id, element) do
    DB.transaction(fn ->
      %__MODULE__{id: id, member: element}
      |> Query.delete_record()
    end)
  end
end
