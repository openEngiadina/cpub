defmodule RDF.FragmentGraph.CSexp do
  @moduledoc """
  Implements the serialization of `RDF.FragmentGraph` based on Canonical S-expressions.

  See https://openengiadina.net/papers/content-addressable-rdf.html for details on the serialization.
  """

  alias RDF.FragmentGraph
  alias RDF.IRI
  alias RDF.Literal

  import RDF.Sigils

  defp mark_encoded(csexp), do: {:encoded_csexp, csexp}

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
          # mark the statements as already encoded as CSexp so `CSexp` does not reencode them as a string
          |> Enum.map(&mark_encoded/1)
      ]
      |> CSexp.encode()
    end
  end

  def encode_term(%IRI{} = iri), do: IRI.to_string(iri)
  def encode_term(%FragmentGraph.FragmentReference{identifier: identifier}), do: ["f", identifier]

  def encode_term(
        %Literal{
          datatype: ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#langString>
        } = literal
      ) do
    [
      "l",
      literal |> Literal.canonical() |> Literal.lexical(),
      literal.datatype |> IRI.to_string(),
      literal.language
    ]
  end

  def encode_term(%Literal{} = literal) do
    [
      "l",
      literal |> Literal.canonical() |> Literal.lexical(),
      literal.datatype |> IRI.to_string()
    ]
  end

  defp encode_statement(statements) do
    statements
    |> Enum.flat_map(fn {predicate, object_set} ->
      object_set
      |> Enum.map(fn object ->
        {encode_term(predicate), encode_term(object)}
      end)
    end)
  end

  defp encode_fragment_statements(fragment_statements) do
    fragment_statements
    |> Enum.flat_map(fn {fragment_identifier, statements} ->
      statements
      |> encode_statement()
      |> Enum.map(fn {predicate, object} ->
        ["fs", fragment_identifier, predicate, object]
        |> CSexp.encode()
      end)
    end)
  end
end
