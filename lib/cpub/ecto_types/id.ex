defmodule CPub.ID do
  @moduledoc """
  Implements the `Ecto.Type` behaviour for `CPub.ID`.
  """

  use Ecto.Type

  alias CPub.Config
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

  @spec get_id_prefix(atom) :: String.t()
  defp get_id_prefix(:actor), do: "actors"
  defp get_id_prefix(:container), do: "containers"
  defp get_id_prefix(:activity), do: "activities"
  defp get_id_prefix(_), do: "objects"

  @spec extend(IRI.t(), URI.t() | String.t()) :: IRI.t()
  def extend(%IRI{} = base, rel) do
    IRI.new!("#{IRI.to_string(base)}/#{rel}")
  end

  @spec merge_with_base_url(URI.t() | String.t()) :: IRI.t()
  def merge_with_base_url(rel) do
    Config.base_url()
    |> URI.merge(rel)
    |> IRI.new!()
  end

  @spec generate(keyword) :: IRI.t()
  def generate(opts \\ []) do
    id_prefix =
      opts
      |> Keyword.get(:type, :objects)
      |> get_id_prefix()

    merge_with_base_url("#{id_prefix}/#{Ecto.UUID.generate()}")
  end

  @spec autogenerate(keyword) :: IRI.t()
  def autogenerate(opts \\ []) do
    generate(opts)
  end

  @doc """
  Returns true if id is a for a local resource, false if not.
  """
  @spec is_local?(IRI.t()) :: boolean
  def is_local?(%IRI{} = iri) do
    iri
    |> IRI.to_string()
    |> String.starts_with?(Config.base_url())
  end

  @doc """
  Validate changeset for a local id. If no id is set a valid id will be generated and set.
  """
  @spec validate(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate(changeset) do
    changeset
    |> ensure_id()
    |> validate_local_id()
  end

  @spec ensure_id(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp ensure_id(%Ecto.Changeset{} = changeset) do
    if is_nil(Ecto.Changeset.get_field(changeset, :id)) do
      Ecto.Changeset.put_change(changeset, :id, generate())
    else
      changeset
    end
  end

  @spec validate_local_id(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_local_id(%Ecto.Changeset{} = changeset) do
    if is_local?(Ecto.Changeset.get_field(changeset, :id)) do
      changeset
    else
      Ecto.Changeset.add_error(changeset, :id, "not a local id")
    end
  end
end
