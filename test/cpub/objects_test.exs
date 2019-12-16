defmodule CPub.ObjectsTest do
  use ExUnit.Case
  use ExUnitProperties
  use CPub.DataCase

  doctest CPub.Objects

  alias CPub.Objects

  test "create and get RDF data" do
    check all data <- RDF.StreamData.graph(),
      max_run_time: 500 do

      # generate an id
      id = CPub.ID.generate()

      # create the object and store in database
      Objects.create_object(%{id: id, data: data})

      # get object from database
      retrieved_object = Objects.get_object!(id)

      assert RDF.Data.equal?(data, retrieved_object.data)
    end
  end

  test "autogenerate id if none specified" do
    assert {:ok, object} = Objects.create_object(%{data: RDF.Graph.new})
  end

  test "object ids are unique" do
    assert {:ok, object} = Objects.create_object(%{data: RDF.Graph.new})
    assert {:error, _} = Objects.create_object(%{data: RDF.Graph.new, id: object.id})
  end

end
