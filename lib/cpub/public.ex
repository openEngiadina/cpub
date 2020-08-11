defmodule CPub.Public do
  @moduledoc """
  Query to access public activities (aka the public timeline).
  """
  import Ecto.Query, only: [from: 2]

  alias CPub.ActivityPub.Activity
  alias CPub.Repo

  alias CPub.NS.ActivityStreams, as: AS

  @doc """
  Returns all public activities.
  """
  @spec get_public :: [Activity.t()]
  def get_public do
    public_collection = RDF.iri(AS.Public)

    from(a in Activity, where: ^public_collection in a.recipients)
    |> Repo.all()
    |> Repo.preload([:activity_object, :object])
  end
end
