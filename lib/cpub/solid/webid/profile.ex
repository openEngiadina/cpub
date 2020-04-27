defmodule CPub.Solid.WebID.Profile do
  @moduledoc """
  Solid WebID Profile Document related functionality.

  Check the Solid WebID Profiles Spec for more information:
  https://github.com/solid/solid-spec/blob/master/solid-webid-profiles.md
  """

  alias CPub.ID
  alias CPub.NS.FOAF

  @spec create(RDF.Description.t(), map) :: RDF.Description.t()
  def create(default_profile, %{username: username}) do
    me = ID.merge_with_base_url("users/#{username}/me")

    web_id_profile =
      me
      |> RDF.Description.new()
      |> RDF.Description.add(RDF.type(), RDF.iri(FOAF.Person))
      |> RDF.Description.add(FOAF.name(), username)
      |> RDF.Description.add(FOAF.nick(), username)

    default_profile
    |> RDF.Description.add(RDF.type(), RDF.iri(FOAF.PersonalProfileDocument))
    |> RDF.Description.add(FOAF.primaryTopic(), me)
    |> RDF.Data.merge(web_id_profile)
  end
end
