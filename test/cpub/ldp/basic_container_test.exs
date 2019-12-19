defmodule CPub.LDP.BasicContainerTest do

  use ExUnit.Case
  use ExUnitProperties
  use CPub.DataCase

  doctest CPub.LDP.BasicContainer

  alias CPub.LDP.BasicContainer
  alias CPub.LDP

  test "create" do
    assert {:ok, %BasicContainer{}} = LDP.create_basic_container()
  end

  test "add elements to container" do
    # create a container
    assert {:ok, %BasicContainer{} = container} = LDP.create_basic_container()

    # add some random elements
    check all element <- RDF.StreamData.iri() do
      assert {:ok, container} =
        container
        |> BasicContainer.add(element)
        |> BasicContainer.changeset()
        |> CPub.Repo.update()

      assert Enum.member?(LDP.get_basic_container!(container.id), element)
    end

  end

end
