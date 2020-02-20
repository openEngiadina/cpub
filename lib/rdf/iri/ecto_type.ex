defmodule RDF.IRI.EctoType do

  use Ecto.Type

  alias RDF.IRI

  def type do
    :string
  end

  # cast from string
  def cast(id) when is_binary(id) do
    with iri <- IRI.new(id) do
      if IRI.valid? iri do
        {:ok, iri}
      else
        {:error, "invalid IRI"}
      end
    end
  end

  # cast from IRI
  def cast(%IRI{} = iri)  do
    {:ok, iri}
  end

  # casting from anything else is an error
  def cast(_) do
    :error
  end

  # encode as string
  def dump(%IRI{} = iri) do
    {:ok, IRI.to_string(iri)}
  end

  def dump(_) do
    :error
  end

  def load(data) when is_binary(data) do
    {:ok, IRI.new(data)}
  end

end
