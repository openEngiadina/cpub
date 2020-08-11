defmodule RDF.JSON.Encoder do
  @moduledoc false

  use RDF.Serialization.Encoder

  alias RDF.{BlankNode, Data, Description, Graph, IRI, Literal, Serialization, Statement}

  @type value_object :: %{atom => String.t()}

  @impl Serialization.Encoder
  @spec encode(Description.t() | Graph.t(), [Jason.encode_opt()]) ::
          {:ok, String.t()} | {:error, Jason.EncodeError.t() | Exception.t()}
  def encode(data, opts \\ []) do
    with {:ok, as_map} <- from_rdf(data, opts), do: Jason.encode(as_map)
  end

  @spec from_rdf(Description.t() | Graph.t(), keyword) ::
          {:ok, %{String.t() => %{String.t() => [value_object]}}}
  def from_rdf(data, _opts \\ []) do
    json =
      data
      |> Data.descriptions()
      |> Enum.reduce(%{}, fn %Description{subject: subject} = description, root_object ->
        Map.put(root_object, subject_key(subject), subject_object(description))
      end)

    {:ok, json}
  end

  @spec from_rdf!(Description.t() | Graph.t(), keyword) ::
          %{String.t() => %{String.t() => [value_object]}}
  def from_rdf!(data, opts \\ []) do
    with {:ok, data} <- from_rdf(data, opts), do: data
  end

  @spec subject_key(Statement.subject()) :: String.t()
  defp subject_key(%IRI{} = subject), do: IRI.to_string(subject)
  defp subject_key(%BlankNode{id: id}), do: "_:#{id}"

  @spec subject_object(Description.t()) :: %{String.t() => [value_object]}
  defp subject_object(description) do
    description
    |> Description.predicates()
    |> Enum.reduce(%{}, fn predicate, subject_object ->
      Map.put(subject_object, IRI.to_string(predicate), value_array(description, predicate))
    end)
  end

  @spec value_array(Description.t(), Statement.coercible_predicate()) :: [value_object]
  defp value_array(description, predicate) do
    description
    |> Description.get(predicate)
    |> Enum.map(&value_object/1)
  end

  @spec value_object(Statement.object()) :: value_object
  defp value_object(%IRI{} = object), do: %{type: "uri", value: IRI.to_string(object)}
  defp value_object(%BlankNode{id: id}), do: %{type: "bnode", value: "_:#{id}"}

  defp value_object(%Literal{} = literal) do
    # %{type: "literal", value: RDF.Literal.lexical(literal)}
    %{type: "literal", value: Literal.canonical_lexical(literal)}
    |> put_literal_datatype(literal)
    |> put_literal_language(literal)
  end

  @spec put_literal_datatype(value_object, Literal.t()) :: value_object
  defp put_literal_datatype(value_object, literal) do
    if Literal.has_datatype?(literal) do
      Map.put(value_object, :datatype, literal |> Literal.datatype_id() |> IRI.to_string())
    else
      value_object
    end
  end

  @spec put_literal_language(value_object, Literal.t()) :: value_object
  defp put_literal_language(value_object, literal) do
    if Literal.has_language?(literal) do
      Map.put(value_object, :lang, literal |> Literal.language())
    else
      value_object
    end
  end
end
