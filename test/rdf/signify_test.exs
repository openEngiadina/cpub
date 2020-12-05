# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule RDF.SignifyTest do
  use ExUnit.Case
  use CPub.RDFCase

  doctest RDF.Signify

  describe "SecretKey.generate/0" do
    test "generate a new key pair" do
      assert %RDF.Signify.SecretKey{} = RDF.Signify.SecretKey.generate()
    end
  end

  describe "sign/3 and verify/0" do
    test "sign and verify valid signature" do
      assert sk = RDF.Signify.SecretKey.generate()
      assert signature = RDF.Signify.sign(EX.hello(), sk)
      assert {:ok, _} = RDF.Signify.verify(signature)
    end
  end
end
