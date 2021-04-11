# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.NS do
  @moduledoc """
  Namespaces used by CPub
  """

  use RDF.Vocabulary.Namespace

  defvocab(ActivityStreams,
    base_iri: "https://www.w3.org/ns/activitystreams#",
    file: "activitystreams2.ttl"
  )

  defvocab(LDP,
    base_iri: "http://www.w3.org/ns/ldp#",
    file: "ldp.ttl",
    ignore: ["PreferEmptyContainer"]
  )

  defvocab(DCTERMS,
    base_iri: "http://purl.org/dc/terms/",
    file: "dcterms.ttl",
    ignore: ["ISO639-2", "ISO639-3"]
  )

  defvocab(ACL,
    base_iri: "http://www.w3.org/ns/auth/acl#",
    file: "acl.ttl"
  )

  defvocab(FOAF,
    base_iri: "http://xmlns.com/foaf/0.1/",
    file: "foaf.ttl"
  )

  defvocab(SOLID,
    base_iri: "http://www.w3.org/ns/solid/terms#",
    file: "solid.ttl"
  )

  defvocab(Litepub,
    base_iri: "http://litepub.social/ns#",
    file: "litepub.ttl"
  )
end
