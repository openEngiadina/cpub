defmodule CPub.Repo do
  use Ecto.Repo,
    otp_app: :cpub,
    adapter: Ecto.Adapters.Postgres

  import Ecto.Query, only: [from: 2]

  alias CPub.Users.User

  # TODO implement public accessible resources
  def get_resource(queryable, id, nil) do
    get(queryable, id)
  end

  @doc """
  Get a resource that a user is authorized to read.
  """
  def get_resource(queryable, id, %User{} = user) do
    query = from resource in queryable,
      join: authorization in assoc(resource, :authorizations),
      where: authorization.mode_read == true,
      where: authorization.user_id == ^user.id,
      where: resource.id == ^id,
      select: resource

    one(query)
  end
end
