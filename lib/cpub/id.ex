defmodule CPub.ID do

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

  def generate() do
    URI.merge(
      Application.get_env(:cpub, :base_url),
      "objects/" <> Ecto.UUID.generate())
    |> IRI.new!
  end

  def autogenerate() do
    generate()
  end

  @doc """
  Returns true if id is a for a local resource, false if not.
  """
  def is_local?(%IRI{} = iri) do
    iri
    |> IRI.to_string
    |> String.starts_with?(Application.get_env(:cpub, :base_url))
  end

  @doc """
  Validate changeset for a local id. If no id is set a valid id will be generated and set.
  """
  def validate(changeset) do
    changeset

    # autogenerate an id if not set
    |> (fn changeset ->
      if is_nil(Ecto.Changeset.get_field(changeset, :id)) do
        changeset
        |> Ecto.Changeset.put_change(:id, generate())
      else
        changeset
      end
    end).()

    # check that id is local
    |> (fn changeset ->
      if is_local?(Ecto.Changeset.get_field(changeset, :id)) do
        changeset
      else
        changeset
        |> Ecto.Changeset.add_error(:id, "not a local id")
      end
    end).()
  end
end
