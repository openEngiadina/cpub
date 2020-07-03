defmodule RDF.FragmentGraph.JSON do
  @moduledoc """
  Custom encoding of `FragmentGraph` as JSON.

  This is only used internally to store an `RDF.FragmentGraph` as an `Ecto.Type`. It should not be exposed as it is not a standard encoding.

  Encoding is based on RDF/JSON.
  """

  alias RDF.{FragmentGraph, IRI, LangString, Literal}

  @type encoded_object :: %{String.t() => String.t()}

  @doc """
  Encode a `RDF.FragmentGraph` as a JSON encodable map.
  """
  @spec from_rdf(FragmentGraph.t()) :: map
  def from_rdf(%FragmentGraph{} = data) do
    with encoded_base_subject <- IRI.to_string(data.base_subject),
         encoded_statements <- data.statements |> encode_statements,
         encoded_fragment_statements <- data.fragment_statements |> encode_fragment_statements() do
      {:ok,
       %{
         "base_subject" => encoded_base_subject,
         "statements" => encoded_statements,
         "fragment_statements" => encoded_fragment_statements
       }}
    end
  end

  def from_rdf!(data) do
    with {:ok, data} <- from_rdf(data), do: data
  end

  def to_rdf(data) do
    with base_subject <- IRI.new!(Map.get(data, "base_subject")),
         statements <- decode_statements(Map.get(data, "statements", %{})),
         fragment_statements <-
           decode_fragment_statements(Map.get(data, "fragment_statements", %{})) do
      {:ok,
       %FragmentGraph{
         base_subject: base_subject,
         statements: statements,
         fragment_statements: fragment_statements
       }}
    end
  end

  def to_rdf!(data) do
    with {:ok, data} <- to_rdf(data), do: data
  end

  @spec encode_statements(FragmentGraph.statements()) :: %{String.t() => encoded_object()}
  defp encode_statements(statements) do
    statements
    |> Enum.map(fn {p, objects} ->
      {IRI.to_string(p), objects |> Enum.map(&encode_object/1)}
    end)
  end

  @spec decode_statements(%{String.t() => encoded_object()}) :: FragmentGraph.statements()
  defp decode_statements([]), do: %{}

  defp decode_statements(statements_object) do
    statements_object
    |> Enum.reduce(Map.new(), fn {encoded_p, encoded_objects}, statements ->
      with predicate <- IRI.new!(encoded_p),
           objects <-
             encoded_objects
             |> Enum.reduce(MapSet.new(), fn object, mapset ->
               MapSet.put(mapset, object |> decode_object())
             end) do
        Map.put(statements, predicate, objects)
      end
    end)
  end

  defp encode_fragment_statements(fragment_statements) do
    fragment_statements
    |> Enum.map(fn {fragment_id, statements} ->
      {fragment_id, statements |> encode_statements()}
    end)
  end

  defp decode_fragment_statements([]), do: %{}

  defp decode_fragment_statements(fragment_statments_object) do
    fragment_statments_object
    |> Enum.reduce(Map.new(), fn {fragment_id, statements}, fragment_statements ->
      Map.put(fragment_statements, fragment_id, statements |> decode_statements())
    end)
  end

  @spec encode_object(FragmentGraph.object()) :: encoded_object
  defp encode_object(%IRI{} = object), do: %{"type" => "uri", "value" => IRI.to_string(object)}

  defp encode_object(%Literal{} = literal) do
    %{"type" => "literal", "value" => literal.value}
    |> encode_literal_datatype(literal)
    |> encode_literal_language(literal)
  end

  defp decode_object(%{"type" => "uri", "value" => value}) do
    IRI.new!(value)
  end

  defp decode_object(%{"type" => "literal", "value" => value} = object) do
    value
    |> Literal.new!()
    |> decode_literal_datatype(object)
    |> decode_literal_language(object)
  end

  @spec encode_literal_datatype(encoded_object, Literal.t()) :: encoded_object
  defp encode_literal_datatype(value_object, literal) do
    if Literal.has_datatype?(literal) do
      Map.put(value_object, "datatype", literal.datatype.value)
    else
      value_object
    end
  end

  defp decode_literal_datatype(literal, %{"datatype" => datatype}) do
    Literal.new(literal.value, datatype: datatype)
  end

  defp decode_literal_datatype(literal, _), do: literal

  @spec encode_literal_language(encoded_object, Literal.t()) :: encoded_object
  defp encode_literal_language(value_object, literal) do
    if Literal.has_language?(literal) do
      Map.put(value_object, "lang", literal.language)
    else
      value_object
    end
  end

  defp decode_literal_language(literal, %{"lang" => language}) do
    LangString.new!(literal, language: language)
  end

  defp decode_literal_language(literal, _), do: literal
end
