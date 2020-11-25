# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.FragmentGraphTest do
  use ExUnit.Case
  use ExUnitProperties
  use CPub.RDFCase

  alias RDF.Data
  alias RDF.Description
  alias RDF.FragmentGraph

  doctest RDF.FragmentGraph

  def empty_fragment_graph?(%FragmentGraph{} = fg) do
    fg.fragment_statements == %{} and fg.statements == %{}
  end

  def is_base_subject?(%FragmentGraph{} = fg, base_subject) do
    fg.base_subject == RDF.IRI.new!(base_subject)
  end

  describe "new/1" do
    test "creates an empty FragmentGraph" do
      fg = FragmentGraph.new(EX.Foo)
      assert empty_fragment_graph?(fg)
      assert is_base_subject?(fg, EX.Foo)
    end
  end

  describe "add/3" do
    test "adds a statement" do
      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add(RDF.type(), EX.Bar)

      assert RDF.Data.statements(fg) == [RDF.Triple.new(EX.Foo, RDF.type(), EX.Bar)]
    end

    test "adds a statement with a fragment reference" do
      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add(RDF.type(), FragmentGraph.FragmentReference.new("abc"))

      assert RDF.Data.statements(fg) == [
               RDF.Triple.new(EX.Foo, RDF.type(), ~I<http://example.com/Foo#abc>)
             ]

      # set a new base subject to make sure that the fragment reference
      # is stored as a fragment reference (and not as an IRI)
      assert RDF.Data.statements(fg |> FragmentGraph.set_base_subject(EX.Foo2)) == [
               RDF.Triple.new(EX.Foo2, RDF.type(), ~I<http://example.com/Foo2#abc>)
             ]
    end
  end

  describe "delete/3" do
    test "deletes a statement" do
      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add(RDF.type(), EX.Bar)

      assert RDF.Data.statements(fg) == [RDF.Triple.new(EX.Foo, RDF.type(), EX.Bar)]

      assert empty_fragment_graph?(fg |> FragmentGraph.delete(RDF.type(), EX.Bar))
    end
  end

  describe "add_fragment_statement/3" do
    test "adds a fragment statement" do
      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add_fragment_statement("abc", RDF.type(), EX.Bar)

      triple = RDF.Triple.new(~I<http://example.com/Foo#abc>, RDF.type(), EX.Bar)

      assert RDF.Data.statements(fg) == [triple]
    end
  end

  describe "delete_fragment_statement/3" do
    test "deletes a fragment statement" do
      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add_fragment_statement("abc", RDF.type(), EX.Bar)

      triple = RDF.Triple.new(~I<http://example.com/Foo#abc>, RDF.type(), EX.Bar)

      assert RDF.Data.statements(fg) == [triple]

      assert empty_fragment_graph?(
               fg
               |> FragmentGraph.delete_fragment_statement("abc", RDF.type(), EX.Bar)
             )
    end
  end

  describe "add/2" do
    test "adds a single statment" do
      triple = RDF.Triple.new(EX.Foo, RDF.type(), EX.Bar)

      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add(triple)

      assert RDF.Data.statements(fg) == [triple]
    end

    test "does not add unrelated statement" do
      triple = RDF.Triple.new(EX.Foo2, RDF.type(), EX.Bar)

      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add(triple)

      assert empty_fragment_graph?(fg)
    end

    test "adds a list of statements" do
      statements = [
        RDF.Triple.new(EX.Foo, RDF.type(), EX.Bar),
        RDF.Triple.new(EX.Foo, EX.p1(), "Hello!"),
        RDF.Triple.new(~I<http://example.com/Foo#abc>, EX.p2(), 42),
        # this statement will not be added to the Fragment Graph
        RDF.Triple.new(EX.Foo2, EX.p3(), 3.141)
      ]

      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add(statements)

      assert MapSet.equal?(
               FragmentGraph.statements(fg) |> MapSet.new(),
               statements |> Enum.take(3) |> MapSet.new()
             )
    end

    test "adds RDF.Data" do
      description =
        Description.new(EX.Foo)
        |> Description.add(RDF.type(), EX.Bar)
        |> Description.add(EX.p(), EX.FooBar)

      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add(description)

      assert FragmentGraph.description(fg, EX.Foo) == description
    end
  end

  describe "delete/2" do
    test "deletes a single statement" do
      triple = RDF.Triple.new(EX.Foo, RDF.type(), EX.Bar)

      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add(triple)
        |> FragmentGraph.delete(triple)

      assert empty_fragment_graph?(fg)
    end

    test "deletes a list of statements" do
      statements = [
        RDF.Triple.new(EX.Foo, RDF.type(), EX.Bar),
        RDF.Triple.new(EX.Foo, EX.p1(), "Hello!"),
        RDF.Triple.new(~I<http://example.com/Foo#abc>, EX.p2(), 42),
        # this statement will not be added to the Fragment Graph
        RDF.Triple.new(EX.Foo2, EX.p3(), 3.141)
      ]

      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add(statements)
        |> FragmentGraph.delete(statements)

      assert empty_fragment_graph?(fg)
    end

    test "deletes RDF.Data" do
      description =
        Description.new(EX.Foo)
        |> Description.add(RDF.type(), EX.Bar)
        |> Description.add(EX.p(), EX.FooBar)

      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add(description)
        |> FragmentGraph.delete(description)

      assert empty_fragment_graph?(fg)
    end
  end

  describe "set_base_subject/2" do
    test "sets the base subject" do
      description =
        Description.new(EX.Foo)
        |> Description.add(RDF.type(), EX.Bar)
        |> Description.add(EX.property(), 5)

      fg =
        FragmentGraph.new(EX.Foo)
        |> FragmentGraph.add(description)

      assert is_base_subject?(fg, EX.Foo)

      new_iri = ~I<http://new-iri.org/>

      fg = FragmentGraph.set_base_subject(fg, new_iri)

      assert is_base_subject?(fg, new_iri)
      assert Data.describes?(fg, new_iri)
      assert Data.description(fg, new_iri) |> Description.count() == 2
    end
  end
end
