defmodule RDF.JSON.Decoder do
  @moduledoc false

  use RDF.Serialization.Decoder

  alias RDF.{BlankNode, Graph, IRI, LangString, Literal, Serialization, Triple}

  @impl Serialization.Decoder
  def decode(content, opts \\ []) do
    with {:ok, json_object} <- Jason.decode(content),
         ok_graph <- to_rdf(json_object, opts) do
      ok_graph
    end
  end

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

  def to_rdf!(data, opts \\ []) do
    case to_rdf(data, opts) do
      {:ok, data} ->
        data

      {:error, reason} ->
        raise reason
    end
  end

  defp coerce_subject(subject_key) do
    case subject_key do
      "_:" <> id ->
        BlankNode.new(id)

      iri ->
        IRI.new!(iri)
    end
  end

  defp subject_object_to_triples(subject, subject_object) do
    Enum.reduce(subject_object, [], fn {predicate, value_array}, triples ->
      triples ++ value_array_to_triples(subject, IRI.new!(predicate), value_array)
    end)
  end

  defp value_array_to_triples(subject, predicate, value_array) do
    Enum.map(value_array, fn value_object ->
      value_object_to_triple(subject, predicate, value_object)
    end)
  end

  defp value_object_to_triple(subject, predicate, value_object) do
    Triple.new(subject, predicate, object(value_object))
  end

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

  defp put_literal_datatype(literal, %{"datatype" => datatype}) do
    Literal.new!(literal.value, datatype: datatype)
  end

  defp put_literal_datatype(literal, _value_object), do: literal

  defp put_literal_language(literal, %{"lang" => language}) do
    LangString.new!(literal, language: language)
  end

  defp put_literal_language(literal, _value_object), do: literal
end
