defmodule CPub.ERISTest do
  use ExUnit.Case

  alias CPub.ERIS

  doctest CPub.ERIS

  describe "put/1, get/1" do
    test "put some content and get" do
      quote = "EVERYTHING IS TRUE, EVEN THIS STATEMENT AND FALSE THINGS AND AMBIGUOUS
      THINGS AND HALF TRUE THINGS AND IRRELEVANT THINGS AND MEANINGLESS THINGS
      AND TRUE THINGS; THIS STATEMENT IS FALSE."
      assert {:ok, read_capability} = ERIS.put(quote)
      assert quote = ERIS.decode(read_capability)
    end
  end
end
