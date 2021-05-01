# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.StreamData do
  @moduledoc """
  StreamData generators for RDF data.

  Generation is very basic and limited.
  TODO: Generate nicer RDF data using StreamData.tree
  """

  import StreamData

  alias RDF.{BlankNode, Description, FragmentGraph, Graph, IRI, Literal, Statement, Triple}

  @spec literal :: StreamData.t(Literal.t())
  @dialyzer {:nowarn_function, literal: 0}
  def literal do
    [integer(), string(:printable)]
    |> one_of()
    |> map(&Literal.new/1)
  end

  @spec bnode :: StreamData.t(BlankNode.t())
  @dialyzer {:nowarn_function, bnode: 0}
  def bnode do
    # Note we add ":" to blank node identifier so it gets the same value when
    # deserialized from RDF/JSON.LD. Better would be an equality that can handle
    # mismatch in blank node naming.
    map(positive_integer(), &BlankNode.new/1)
  end

  @spec iri :: StreamData.t(IRI.t())
  @dialyzer {:nowarn_function, iri: 0}
  def iri do
    scheme = one_of([constant("http"), constant("https")])
    host = string(:alphanumeric, max_length: 50)

    path =
      string(:alphanumeric, max_length: 20)
      |> list_of(max_length: 6)
      |> map(&Enum.join(&1, "/"))

    {scheme, host, path}
    |> tuple()
    |> map(fn {scheme, host, path} -> IRI.new!("#{scheme}://#{host}/#{path}") end)
  end

  @spec subject :: StreamData.t(Statement.subject())
  @dialyzer {:nowarn_function, subject: 0}
  def subject, do: one_of([iri(), bnode()])

  @spec object :: StreamData.t(Statement.object())
  @dialyzer {:nowarn_function, object: 0}
  def object, do: one_of([iri(), bnode(), literal()])

  @spec predicate :: StreamData.t(Statement.predicate())
  @dialyzer {:nowarn_function, predicate: 0}
  def predicate, do: iri()

  @spec triple :: StreamData.t(Triple.t())
  @dialyzer {:nowarn_function, triple: 0}
  def triple do
    {subject(), predicate(), object()}
    |> tuple()
    |> map(&Triple.new/1)
  end

  @spec description :: StreamData.t(Description.t())
  @dialyzer {:nowarn_function, description: 0}
  def description do
    {subject(), {predicate(), object()} |> list_of(min_length: 1)}
    |> map(fn {subject, predicate_objects} ->
      Enum.reduce(
        predicate_objects,
        Description.new(subject),
        &Description.add(&2, elem(&1, 0), elem(&1, 1))
      )
    end)
  end

  @spec graph :: StreamData.t(Graph.t())
  @dialyzer {:nowarn_function, graph: 0}
  def graph do
    triple()
    |> list_of()
    |> map(&Graph.new/1)
  end

  @spec fragment_graph :: StreamData.t(FragmentGraph.t())
  @dialyzer {:nowarn_function, fragment_graph: 0}
  def fragment_graph do
    fragment_identifier = string(:alphanumeric, min_length: 1)
    predicate = iri()
    object = one_of([iri(), literal()])
    statements = {predicate, object} |> list_of
    fragment_statements = {fragment_identifier, predicate, object} |> list_of

    {statements, fragment_statements}
    |> map(fn {statements, fragment_statements} ->
      FragmentGraph.new("urn:dummy")
      |> add_statements_to_fg(statements)
      |> add_fragment_statements_to_fg(fragment_statements)
      |> FragmentGraph.finalize(&CPub.Magnet.fragment_graph_finalizer/1)
    end)
  end

  @spec add_statements_to_fg(FragmentGraph.t(), [Statement.t()]) :: FragmentGraph.t()
  defp add_statements_to_fg(fg, statements) do
    Enum.reduce(statements, fg, fn {p, o}, fg -> FragmentGraph.add(fg, p, o) end)
  end

  @spec add_fragment_statements_to_fg(FragmentGraph.t(), [Statement.t()]) :: FragmentGraph.t()
  defp add_fragment_statements_to_fg(fg, fragment_statements) do
    Enum.reduce(fragment_statements, fg, fn {fid, p, o}, fg ->
      FragmentGraph.add_fragment_statement(fg, fid, p, o)
    end)
  end
end
