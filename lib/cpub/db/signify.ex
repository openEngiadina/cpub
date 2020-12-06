# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Signify do
  @moduledoc """
  CPub database table that indexes valid `RDF.Signify` signatures.
  """

  use Memento.Table,
    attributes: [:id, :public_key, :message],
    index: [:message],
    type: :set

  defp insert!(fg, public_key, message) do
    CPub.DB.transaction(fn ->
      case CPub.ERIS.put(fg) do
        {:ok, read_capability} ->
          %__MODULE__{
            id: read_capability,
            public_key: RDF.Signify.PublicKey.to_iri(public_key),
            message: message
          }
          |> CPub.DB.write()

        _ ->
          CPub.DB.abort(:can_not_add_signature)
      end
    end)
  end

  @doc """
  Verify signature and add to index if valid.
  """
  def insert(%RDF.FragmentGraph{} = fg) do
    case RDF.Signify.verify(fg) do
      {:ok, %{message: message, public_key: public_key}} ->
        insert!(fg, public_key, message)

      _ ->
        :invalid_signature
    end
  end
end
