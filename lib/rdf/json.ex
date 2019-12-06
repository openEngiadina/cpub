defmodule RDF.JSON do
  @moduledoc """
  `RDF.JSON` provides support for reading and writing the RDF 1.1 JSON Alternate Serialization (RDF/JSON) format.

  see <https://www.w3.org/TR/rdf-json/>
  """

  use RDF.Serialization.Format

  import RDF.Sigils

  @id ~I<http://www.w3.org/TR/rdf-json>
  @name :rdf_json
  @extension "rj"
  @media_type "application/rdf+json"

end
