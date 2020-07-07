defmodule RDF.FragmentGraphTest do
  use ExUnit.Case
  use ExUnitProperties

  import RDF.Sigils
  alias RDF.FragmentGraph
  alias RDF.{Data, Description}

  doctest RDF.FragmentGraph

  test "create an empty FragmentGraph" do
    fg = FragmentGraph.new(~I<http://example.com/>)
    assert Data.statements(fg) == []
    assert Data.subjects(fg) == MapSet.new()
    refute Data.describes?(fg, ~I<http://example.com/>)

    assert Data.description(fg, ~I<http://example.com/>) ==
             Description.new(~I<http://example.com/>)
  end

  test "create a FragmentGraph with a single statement" do
    triple = {~I<http://example.com/>, RDF.type(), ~I<http://something.org/>}

    fg =
      FragmentGraph.new(~I<http://example.com/>)
      |> FragmentGraph.add(triple)

    assert Data.statements(fg) == [triple]
    assert Data.subjects(fg) == [triple |> elem(0)] |> MapSet.new()
    assert Data.describes?(fg, triple |> elem(0))

    description =
      Description.new(~I<http://example.com/>)
      |> Description.add(RDF.type(), ~I<http://something.org/>)

    assert Data.description(fg, ~I<http://example.com/>) == description

    assert fg[~I<http://example.com/>] == description
    assert fg[:base_subject] == description
  end

  test "create a FragmentGraph with a single fragment statement" do
    triple = {~I<http://example.com/#abc>, RDF.type(), ~I<http://something.org/>}

    fg =
      FragmentGraph.new(~I<http://example.com/>)
      |> FragmentGraph.add(triple)

    assert Data.statements(fg) == [triple]
    assert Data.subjects(fg) == [triple |> elem(0)] |> MapSet.new()
    assert Data.describes?(fg, triple |> elem(0))

    description =
      Description.new(~I<http://example.com/#abc>)
      |> Description.add(RDF.type(), ~I<http://something.org/>)

    assert Data.description(fg, ~I<http://example.com/#abc>) == description
    assert fg["abc"] == description
    assert fg[~I<http://example.com/#abc>] == description
    assert fg[:base_subject] == nil
  end

  test "create a FragmentGraph with a statement and fragment statement" do
    iri = ~I<http://example.com/>

    description =
      Description.new(iri)
      |> Description.add(RDF.type(), ~I<http://something.org/>)
      |> Description.add(~I<http://example.com/property>, 5)

    fragment_iri = ~I<http://example.com/#abc>

    fragment_description =
      Description.new(fragment_iri)
      |> Description.add(RDF.type(), ~I<http://something.org/else>)
      |> Description.add(~I<http://example.com/property2>, "hello")

    fg =
      FragmentGraph.new(iri)
      |> FragmentGraph.add(description)
      |> FragmentGraph.add(fragment_description)

    assert Data.subjects(fg) ==
             MapSet.union(
               RDF.Data.subjects(description),
               RDF.Data.subjects(fragment_description)
             )

    assert Data.describes?(fg, iri)
    assert Data.describes?(fg, fragment_iri)

    assert Data.statements(fg) ==
             Data.statements(description) ++ Data.statements(fragment_description)

    assert Data.descriptions(fg) == [description, fragment_description]
    assert fg[:base_subject] == description
    assert fg["abc"] == fragment_description
  end

  test "rename base_subject" do
    iri = ~I<http://example.com/>

    description =
      Description.new(iri)
      |> Description.add(RDF.type(), ~I<http://something.org/>)
      |> Description.add(~I<http://example.com/property>, 5)

    fg =
      FragmentGraph.new(iri)
      |> FragmentGraph.add(description)

    assert Data.description(fg, iri) == description

    new_iri = ~I<http://new-iri.org/>

    fg = FragmentGraph.set_base_subject(fg, new_iri)

    assert Data.describes?(fg, new_iri)
    assert Data.description(fg, new_iri) |> Description.count() == 2
  end

  test "coerce_iri recognizes base_subject" do
    assert FragmentGraph.coerce_iri(~I<http://example.com/>, base_subject: ~I<http://example.com/>) ==
             :base_subject
  end

  test "coerce_iri recognizes fragment" do
    assert FragmentGraph.coerce_iri(RDF.IRI.new("http://example.com/#abc"),
             base_subject: ~I<http://example.com/>
           ) == %FragmentGraph.FragmentReference{identifier: "abc"}
  end

  test "coerce_iri returns unchanged IRI for unrelated IRI" do
    assert FragmentGraph.coerce_iri(~I<http://example.com/>,
             base_subject: ~I<http://example.com/abc>
           ) == ~I<http://example.com/>
  end
end
