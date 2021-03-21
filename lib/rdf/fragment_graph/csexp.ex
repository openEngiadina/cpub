# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.FragmentGraph.CSexp do
  @moduledoc """
  Implements the serialization of `RDF.FragmentGraph` based on Canonical
  S-expressions.

  See https://openengiadina.net/papers/content-addressable-rdf.html for details
  on the serialization.
  """

  alias RDF.FragmentGraph
  alias RDF.IRI
  alias RDF.Literal

  @spec encode(FragmentGraph.t()) :: String.t()
  def encode(%FragmentGraph{} = fg) do
    with encoded_statements <-
           fg.statements
           |> encode_statement()
           |> Enum.map(fn {p, o} -> ["s", p, o] |> CSexp.encode() end)
           |> Enum.sort(),
         encoded_fragment_statements <-
           fg.fragment_statements
           |> encode_fragment_statements()
           |> Enum.sort() do
      [
        "rdf"
        | (encoded_statements ++ encoded_fragment_statements)
          # mark the statements as already encoded as CSexp so `CSexp` does not
          # re-encode them as a string
          |> Enum.map(&mark_encoded/1)
      ]
      |> CSexp.encode()
    end
  end

  @doc """
  Decode a `RDF.FragmentGraph` from a binary CSexp.
  """
  @spec decode(String.t(), RDF.Statement.coercible_subject()) :: FragmentGraph.t()
  def decode(binary, base_subject \\ IRI.new("urn:dummy")) do
    with {:ok, [_rdf | statements]} <- CSexp.decode(binary) do
      Enum.reduce(statements, FragmentGraph.new(base_subject), &decode_and_add_statement/2)
    end
  end

  @spec encode_term(IRI.t() | Literal.t() | FragmentGraph.FragmentReference.t()) ::
          CSexp.t() | String.t()
  def encode_term(%IRI{} = iri), do: IRI.to_string(iri)
  def encode_term(%FragmentGraph.FragmentReference{identifier: identifier}), do: ["f", identifier]

  def encode_term(%Literal{literal: %RDF.LangString{}} = literal) do
    [
      "l",
      literal |> Literal.canonical_lexical(),
      literal |> Literal.datatype_id() |> IRI.to_string(),
      literal |> Literal.language()
    ]
  end

  def encode_term(%Literal{} = literal) do
    [
      "l",
      literal |> Literal.canonical_lexical(),
      literal |> Literal.datatype_id() |> IRI.to_string()
    ]
  end

  @spec mark_encoded(String.t()) :: {:encoded_csexp, String.t()}
  defp mark_encoded(csexp), do: {:encoded_csexp, csexp}

  @spec encode_statement(FragmentGraph.statements()) :: [{String.t(), CSexp.t() | String.t()}]
  defp encode_statement(statements) do
    Enum.flat_map(statements, fn {predicate, object_set} ->
      Enum.map(object_set, fn object -> {encode_term(predicate), encode_term(object)} end)
    end)
  end

  @spec encode_fragment_statements(FragmentGraph.statements()) :: [String.t()]
  defp encode_fragment_statements(fragment_statements) do
    Enum.flat_map(fragment_statements, fn {fragment_identifier, statements} ->
      statements
      |> encode_statement()
      |> Enum.map(fn {predicate, object} ->
        CSexp.encode(["fs", fragment_identifier, predicate, object])
      end)
    end)
  end

  @spec decode_term(CSexp.t() | String.t()) ::
          IRI.t() | Literal.t() | FragmentGraph.FragmentReference.t()
  defp decode_term(term) do
    case term do
      ["f", id] ->
        FragmentGraph.FragmentReference.new(id)

      ["l", value, datatype] ->
        Literal.new(value, datatype: datatype)

      ["l", value, datatype, language] ->
        Literal.new(value, datatype: datatype, language: language)

      iri when is_binary(iri) ->
        IRI.new(iri)
    end
  end

  @spec decode_and_add_statement(CSexp.t(), FragmentGraph.t()) :: FragmentGraph.t()
  defp decode_and_add_statement(statement, fg) do
    case statement do
      ["s", p, o] ->
        FragmentGraph.add(fg, decode_term(p), decode_term(o))

      ["fs", f, p, o] ->
        FragmentGraph.add_fragment_statement(fg, f, decode_term(p), decode_term(o))
    end
  end
end
