defmodule RDF.IRI.EctoType do
  @moduledoc """
  Implements the `Ecto.Type` behaviour for `RDF.IRI`.
  """

  use Ecto.Type

  alias RDF.IRI

  @spec type :: :string
  def type, do: :string

  @spec cast(IRI.t() | String.t() | any) :: {:ok, IRI.t()} | :error
  def cast(id) when is_binary(id) do
    with iri <- IRI.new(id),
         true <- IRI.valid?(iri) do
      {:ok, iri}
    else
      _ ->
        :error
    end
  end

  def cast(%IRI{} = iri), do: {:ok, iri}
  def cast(_), do: :error

  @spec dump(IRI.t() | any) :: {:ok, IRI.t()} | :error
  def dump(%IRI{} = iri), do: {:ok, IRI.to_string(iri)}
  def dump(_), do: :error

  @spec load(String.t()) :: {:ok, IRI.t()}
  def load(data) when is_binary(data), do: {:ok, IRI.new(data)}
end
