defmodule CPub.LDP.RDFSourceTest do
  use ExUnit.Case
  use ExUnitProperties
  use CPub.DataCase

  doctest CPub.LDP.RDFSource

  alias CPub.LDP

  test "create and get RDF data" do
    check all data <- RDF.StreamData.graph(),
      max_run_time: 500 do

      # generate an id
      id = CPub.ID.generate()

      # create the object and store in database
      LDP.create_rdf_source(id: id, data: data)

      # get RDFSource from database
      retrieved = LDP.get_rdf_source!(id)

      assert RDF.Data.equal?(data, retrieved.data)
    end
  end

  test "autogenerate id if none specified" do
    assert {:ok, rdf_source} = LDP.create_rdf_source(data: RDF.Graph.new)
  end

  test "RDF Source ids are unique" do
    assert {:ok, rdf_source} = LDP.create_rdf_source(data: RDF.Graph.new)
    assert {:error, _} = LDP.create_rdf_source(data: RDF.Graph.new, id: rdf_source.id)
  end

end
