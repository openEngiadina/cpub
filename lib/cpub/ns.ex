defmodule CPub.NS do
  @moduledoc """
  Namespaces used by CPub
  """

  use RDF.Vocabulary.Namespace

  defvocab ActivityStreams,
    base_iri: "http://www.w3.org/ns/activitystreams#",
    file: "activitystreams2.ttl"

end
