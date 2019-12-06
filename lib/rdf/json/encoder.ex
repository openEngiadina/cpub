defmodule RDF.JSON.Encoder do
  @moduledoc false

  use RDF.Serialization.Encoder

  @impl RDF.Serialization.Encoder
  def encode(data, opts \\ []) do
    with {:ok, as_map} <- from_rdf(data, opts) do
      as_map |> Jason.encode
    end
  end

  def from_rdf(data, _opts \\ []) do
    {:ok, data
    |> RDF.Data.descriptions
    |> Enum.reduce(%{},
     fn (%RDF.Description{subject: subject} = description, root_object) ->
       Map.put(root_object, subject_key(subject), subject_object(description))
     end)}
  end

  def from_rdf!(data, opts \\ []) do
    case from_rdf(data, opts) do
      {:ok, data} -> data
      {:error, reason} -> raise reason
    end
  end

  defp subject_key(%RDF.IRI{} = subject) do
    RDF.IRI.to_string(subject)
  end

  defp subject_key(%RDF.BlankNode{id: id}) do
    "_:" <> id
  end

  defp subject_object(description) do
    description
    |> RDF.Description.predicates
    |> Enum.reduce(%{},
    fn (predicate, subject_object) ->
      Map.put(subject_object, RDF.IRI.to_string(predicate), value_array(description, predicate))
    end)
  end

  defp value_array(description, predicate) do
    RDF.Description.get(description, predicate)
    |> Enum.map(&value_object/1)
  end

  defp value_object(%RDF.IRI{} = object) do
    %{type: "uri", value: RDF.IRI.to_string(object)}
  end

  defp value_object(%RDF.BlankNode{id: id}) do
    %{type: "bnode", value: "_:" <> id}
  end

  defp value_object(%RDF.Literal{} = literal) do
    # %{type: "literal", value: RDF.Literal.lexical(literal)}
    %{type: "literal", value: literal.value}
    |> (fn value_object ->
      if RDF.Literal.has_language? literal do
        Map.put(value_object, "lang", literal.language)
      else
        value_object
      end
    end).()
    |> (fn value_object ->
      if RDF.Literal.has_datatype? literal do
        Map.put(value_object, "datatype", literal.datatype.value)
      else
        value_object
      end
    end).()
  end

end
