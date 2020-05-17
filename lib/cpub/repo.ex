defmodule CPub.Repo do
  use Ecto.Repo,
    otp_app: :cpub,
    adapter: Ecto.Adapters.Postgres,
    migration_timestamps: [type: :naive_datetime_usec]

  @spec get_one(Ecto.Query.t()) :: {:ok, Ecto.Schema.t()} | {:error, :not_found}
  def get_one(%Ecto.Query{} = query) do
    case __MODULE__.one(query) do
      nil -> {:error, :not_found}
      resource -> {:ok, resource}
    end
  end

  @spec get_one(Ecto.Queryable.t(), term) :: {:ok, Ecto.Schema.t()} | {:error, :not_found}
  def get_one(queryable, id) do
    case __MODULE__.get(queryable, id) do
      nil -> {:error, :not_found}
      resource -> {:ok, resource}
    end
  end
end
