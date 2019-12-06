defmodule RDF.JSON.Decoder do
  @moduledoc false

  use RDF.Serialization.Decoder

  alias RDF.{Graph, Triple}
  import RDF.Sigils

  @impl RDF.Serialization.Decoder
  def decode(content, opts \\ []) do
    with {:ok, json_object} <- Jason.decode(content),
         graph = to_rdf(json_object, opts) do
      {:ok, graph}
    end
  end

  def to_rdf(rdf_json_object, opts \\ []) do
    {:ok,
     Enum.reduce(
       rdf_json_object,
       Graph.new,
       fn ({subject_key, subject_object}, graph) ->
         Graph.add(graph,
           subject_key
           |> coerce_subject
           |> subject_object_to_triples(subject_object)
         )
       end
     )}
  end

  def to_rdf!(data, opts \\ []) do
    case to_rdf(data, opts) do
      {:ok, data} -> data
      {:error, reason} -> raise reason
    end
  end

  defp coerce_subject(subject_key) do
    case subject_key do
      "_:" <> id -> RDF.BlankNode.new(id)
      iri -> RDF.IRI.new!(iri)
    end
  end

  defp subject_object_to_triples(subject, subject_object) do
    Enum.reduce(
      subject_object,
      [],
      (fn ({predicate, value_array}, triples) ->
        triples ++
          value_array_to_triples(subject,
            RDF.IRI.new!(predicate),
            value_array
          )
      end)
    )
  end

  defp value_array_to_triples(subject, predicate, value_array) do
    value_array
    |> Enum.map(fn (value_object) ->
      value_object_to_triple(subject, predicate, value_object) end)
  end

  defp value_object_to_triple(subject, predicate, value_object) do
    RDF.Triple.new(
      subject,
      predicate,
      case Map.get(value_object, "type") do
        "uri" ->
          RDF.IRI.new!(Map.get(value_object, "value"))

        "literal" ->
          RDF.Literal.new!(Map.get(value_object, "value"))

          # NOTE: must be a nicer syntax or way of doing this (?)
          |> (fn literal ->
            case Map.get(value_object, "datatype") do
              nil -> literal
              datatype -> RDF.Literal.new!(literal.value, datatype: datatype)
            end
          end).()

          |> (fn literal ->
            case Map.get(value_object, "lang") do
              nil -> literal
              language -> RDF.LangString.new!(literal, language: language)
            end
          end).()

        "bnode" ->
          with "_" <> id <- Map.get(value_object, "value") do
            RDF.BlankNode.new(id)
          end
      end)
  end

end
