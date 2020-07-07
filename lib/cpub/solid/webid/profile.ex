defmodule CPub.Solid.WebID.Profile do
  @moduledoc """
  Solid WebID Profile Document related functionality.

  Check the Solid WebID Profiles Spec for more information:
  https://github.com/solid/solid-spec/blob/master/solid-webid-profiles.md
  """

  alias CPub.ID
  alias CPub.NS.{ActivityStreams, FOAF, SOLID}

  alias RDF.FragmentGraph

  @spec create(FragmentGraph.t()) :: FragmentGraph.t()
  def create(default_profile) do
    username =
      default_profile[:base_subject][ActivityStreams.preferredUsername()]
      |> List.first()

    default_profile
    |> FragmentGraph.add(RDF.type(), FOAF.PersonalProfileDocument)
    |> FragmentGraph.add(FOAF.primaryTopic(), FragmentGraph.fragment_reference("me"))
    |> FragmentGraph.add_fragment_statement("me", RDF.type(), FOAF.Person)
    |> FragmentGraph.add_fragment_statement("me", FOAF.name(), username)
    |> FragmentGraph.add_fragment_statement("me", FOAF.nick(), username)
  end

  @spec fetch_profile(RDF.Graph.t()) :: RDF.Description.t()
  def fetch_profile(%RDF.Graph{} = graph) do
    profile_subject =
      graph
      |> RDF.Graph.subjects()
      |> MapSet.to_list()
      |> Enum.find(&(RDF.iri(FOAF.Person) in (graph[&1][RDF.type()] || [])))

    graph[profile_subject]
  end

  @spec fetch_oidc_issuer(RDF.Description.t()) :: String.t()
  def fetch_oidc_issuer(%RDF.Description{} = descr) do
    with [issuer_iri] <- descr[SOLID.oidcIssuer()], do: issuer_iri.value
  end
end
