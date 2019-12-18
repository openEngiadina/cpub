defmodule CPub.LDP.BasicContainerTest do

  use ExUnit.Case
  use ExUnitProperties
  use CPub.DataCase

  doctest CPub.LDP.BasicContainer

  alias CPub.LDP.BasicContainer

  test "create" do
    assert {:ok, %BasicContainer{}} = BasicContainer.create()
  end

  test "add elements to container" do
    # create a container
    assert {:ok, %BasicContainer{} = container} = BasicContainer.create()

    # add some random elements
    check all element <- RDF.StreamData.iri() do
      assert {:ok, container} =
        container
        |> BasicContainer.add(element)
        |> BasicContainer.changeset()
        |> CPub.Repo.update()

      assert Enum.member?(BasicContainer.get!(container.id), element)
    end

  end

end
