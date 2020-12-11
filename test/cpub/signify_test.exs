# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.SignifyTest do
  use ExUnit.Case
  use CPub.RDFCase

  alias CPub.Signify

  doctest CPub.Signify

  describe "SecretKey.generate/0" do
    test "generate a new key pair" do
      assert %Signify.SecretKey{} = Signify.SecretKey.generate()
    end
  end

  describe "sign/3 and verify/0" do
    test "sign and verify valid signature" do
      message = ERIS.encode_read_capability("Hello")

      assert sk = Signify.SecretKey.generate()
      assert {:ok, signature} = Signify.sign(message, sk)
      assert {:ok, _} = Signify.verify(signature)
    end
  end
end
