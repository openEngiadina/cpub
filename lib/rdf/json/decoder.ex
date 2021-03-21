# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.JSON.Decoder do
  @moduledoc false

  use RDF.Serialization.Decoder

  alias RDF.{BlankNode, Graph, IRI, Literal, Serialization, Statement, Triple}

  @type object :: %{String.t() => String.t()}

  @impl Serialization.Decoder
  @spec decode(iodata, keyword) :: {:ok, Graph.t()} | {:error, Jason.DecodeError.t()}
  def decode(content, opts \\ []) do
    with {:ok, json_object} <- Jason.decode(content), do: to_rdf(json_object, opts)
  end

  @spec to_rdf(%{String.t() => %{String.t() => [object]}}, keyword) :: {:ok, Graph.t()}
  def to_rdf(rdf_json_object, _opts \\ []) do
    rdf =
      Enum.reduce(rdf_json_object, Graph.new(), fn {subject_key, subject_object}, graph ->
        triple =
          subject_key
          |> coerce_subject
          |> subject_object_to_triples(subject_object)

        Graph.add(graph, triple)
      end)

    {:ok, rdf}
  end

  @spec to_rdf!(%{String.t() => %{String.t() => [object]}}, keyword) :: Graph.t()
  def to_rdf!(data, opts \\ []) do
    with {:ok, data} <- to_rdf(data, opts), do: data
  end

  @spec coerce_subject(String.t()) :: Statement.subject()
  defp coerce_subject(subject_key) do
    case subject_key do
      "_:" <> id ->
        BlankNode.new(id)

      iri ->
        IRI.new!(iri)
    end
  end

  @spec subject_object_to_triples(Statement.subject(), %{String.t() => object}) :: [Triple.t()]
  defp subject_object_to_triples(subject, subject_object) do
    Enum.reduce(subject_object, [], fn {predicate, value_array}, triples ->
      triples ++ value_array_to_triples(subject, IRI.new!(predicate), value_array)
    end)
  end

  @spec value_array_to_triples(Statement.subject(), Statement.predicate(), [object]) ::
          [Triple.t()]
  defp value_array_to_triples(subject, predicate, value_array) do
    Enum.map(value_array, fn value_object ->
      value_object_to_triple(subject, predicate, value_object)
    end)
  end

  @spec value_object_to_triple(Statement.subject(), Statement.predicate(), object) :: Triple.t()
  defp value_object_to_triple(subject, predicate, value_object) do
    Triple.new(subject, predicate, object(value_object))
  end

  @spec object(object) :: Statement.object()
  defp object(%{"type" => "uri"} = value_object) do
    IRI.new!(Map.get(value_object, "value"))
  end

  defp object(%{"type" => "literal", "value" => value} = value_object) do
    value
    |> Literal.new!()
    |> put_literal_datatype(value_object)
    |> put_literal_language(value_object)
  end

  defp object(%{"type" => "bnode"} = value_object) do
    with "_:" <> id <- Map.get(value_object, "value"), do: BlankNode.new(id)
  end

  @spec put_literal_datatype(Literal.t(), object) :: Literal.t()
  defp put_literal_datatype(literal, %{"datatype" => datatype}) do
    literal
    |> Literal.value()
    |> Literal.new(datatype: datatype)
  end

  defp put_literal_datatype(literal, _value_object), do: literal

  @spec put_literal_language(Literal.t(), object) :: Literal.t()
  defp put_literal_language(literal, %{"lang" => language}) do
    literal
    |> Literal.value()
    |> Literal.new(language: language)
  end

  defp put_literal_language(literal, _value_object), do: literal
end
