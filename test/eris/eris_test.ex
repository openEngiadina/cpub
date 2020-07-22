defmodule ERISTest do
  @moduledoc false

  use ExUnit.Case
  use ExUnitProperties

  doctest ERIS

  describe "ERIS encoding" do
    property "encode -> decode (small data)" do
      check all(data <- StreamData.binary()) do
        assert {:ok, cap, map} = ERIS.put!(%{}, data)

        assert decoded = ERIS.get(map, cap)

        assert decoded == data
      end
    end

    property "encode -> decode (10kB)" do
      check all(data <- StreamData.binary(min_length: 1024 * 10)) do
        assert {:ok, cap, map} = ERIS.put!(%{}, data)

        assert decoded = ERIS.get(map, cap)

        assert decoded == data
      end
    end
  end
end
