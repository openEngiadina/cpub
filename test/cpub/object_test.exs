defmodule CPub.ObjectTest do
  use ExUnit.Case
  use ExUnitProperties
  use CPub.DataCase
  use CPub.RDFCase

  alias CPub.Object

  doctest CPub.Object

  describe "create/1" do
    property "create a new object from a RDF.FragmentGraph" do
      check all(fragment_graph <- RDF.StreamData.fragment_graph()) do
        assert {:ok, object} = fragment_graph |> Object.create()
        assert object.id == fragment_graph.base_subject
      end
    end

    test "add same graph twice is idempotent" do
      fg =
        RDF.FragmentGraph.new(EX.Foo)
        |> RDF.FragmentGraph.add(RDF.type(), EX.Bar)
        |> RDF.FragmentGraph.add(EX.foobar(), EX.BlaBla)
        |> RDF.FragmentGraph.add_fragment_statement("blups", RDF.type(), EX.Blups)
        |> RDF.FragmentGraph.finalize()

      assert {:ok, object1} = fg |> Object.create()
      assert {:ok, object2} = fg |> Object.create()

      assert object1 == object2
    end
  end
end
