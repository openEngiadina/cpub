defmodule CPub.ID do
  @moduledoc """
  Implements the `Ecto.Type` behaviour for `CPub.ID`.
  """

  use Ecto.Type

  alias RDF.IRI

  def type do
    :string
  end

  # cast from string
  def cast(id) when is_binary(id) do
    with iri <- IRI.new(id),
         true <- IRI.valid?(iri) do
      {:ok, iri}
    else
      _ ->
        {:error, "invalid IRI"}
    end
  end

  # cast from IRI
  def cast(%IRI{} = iri) do
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

  defp get_id_prefix(:actor), do: "actors"
  defp get_id_prefix(:container), do: "containers"
  defp get_id_prefix(:activity), do: "activities"
  defp get_id_prefix(_), do: "objects"

  def extend(%IRI{} = base, rel) do
    IRI.new!("#{IRI.to_string(base)}/#{rel}")
  end

  def merge_with_base_url(rel) do
    Application.get_env(:cpub, :base_url)
    |> URI.merge(rel)
    |> IRI.new!()
  end

  def generate(opts \\ []) do
    id_prefix =
      opts
      |> Keyword.get(:type, :objects)
      |> get_id_prefix()

    merge_with_base_url("#{id_prefix}/#{Ecto.UUID.generate()}")
  end

  def autogenerate(opts \\ []) do
    generate(opts)
  end

  @doc """
  Returns true if id is a for a local resource, false if not.
  """
  def is_local?(%IRI{} = iri) do
    iri
    |> IRI.to_string()
    |> String.starts_with?(Application.get_env(:cpub, :base_url))
  end

  @doc """
  Validate changeset for a local id. If no id is set a valid id will be generated and set.
  """
  def validate(changeset) do
    changeset
    |> ensure_id()
    |> validate_local_id()
  end

  defp ensure_id(%Ecto.Changeset{} = changeset) do
    if is_nil(Ecto.Changeset.get_field(changeset, :id)) do
      Ecto.Changeset.put_change(changeset, :id, generate())
    else
      changeset
    end
  end

  defp validate_local_id(%Ecto.Changeset{} = changeset) do
    if is_local?(Ecto.Changeset.get_field(changeset, :id)) do
      changeset
    else
      Ecto.Changeset.add_error(changeset, :id, "not a local id")
    end
  end
end
