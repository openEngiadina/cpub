defmodule RDF.JSON.Encoder do
  @moduledoc false

  use RDF.Serialization.Encoder

  alias RDF.{BlankNode, Data, Description, IRI, Literal, Serialization}

  @impl Serialization.Encoder
  def encode(data, opts \\ []) do
    with {:ok, as_map} <- from_rdf(data, opts), do: Jason.encode(as_map)
  end

  def from_rdf(data, _opts \\ []) do
    json =
      data
      |> Data.descriptions()
      |> Enum.reduce(%{}, fn %Description{subject: subject} = description, root_object ->
        Map.put(root_object, subject_key(subject), subject_object(description))
      end)

    {:ok, json}
  end

  def from_rdf!(data, opts \\ []) do
    case from_rdf(data, opts) do
      {:ok, data} ->
        data

      {:error, reason} ->
        raise reason
    end
  end

  defp subject_key(%IRI{} = subject) do
    RDF.IRI.to_string(subject)
  end

  defp subject_key(%BlankNode{id: id}) do
    "_:#{id}"
  end

  defp subject_object(description) do
    description
    |> Description.predicates()
    |> Enum.reduce(%{}, fn predicate, subject_object ->
      Map.put(subject_object, IRI.to_string(predicate), value_array(description, predicate))
    end)
  end

  defp value_array(description, predicate) do
    description
    |> Description.get(predicate)
    |> Enum.map(&value_object/1)
  end

  defp value_object(%IRI{} = object) do
    %{type: "uri", value: IRI.to_string(object)}
  end

  defp value_object(%BlankNode{id: id}) do
    %{type: "bnode", value: "_:#{id}"}
  end

  defp value_object(%Literal{} = literal) do
    # %{type: "literal", value: RDF.Literal.lexical(literal)}
    %{type: "literal", value: literal.value}
    |> put_literal_datatype(literal)
    |> put_literal_language(literal)
  end

  defp put_literal_datatype(value_object, literal) do
    if Literal.has_datatype?(literal) do
      Map.put(value_object, "datatype", literal.datatype.value)
    else
      value_object
    end
  end

  defp put_literal_language(value_object, literal) do
    if Literal.has_language?(literal) do
      Map.put(value_object, "lang", literal.language)
    else
      value_object
    end
  end
end
