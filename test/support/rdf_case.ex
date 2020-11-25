# SPDX-FileCopyrightText: 2020 pukkamustard <pukkamustard@posteo.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.RDFCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  use RDF.Vocabulary.Namespace
  defvocab(EX, base_iri: "http://example.com/", terms: [], strict: false)

  using do
    quote do
      alias CPub.RDFCase.EX

      alias RDF.FragmentGraph

      import RDF.Sigils

      @compile {:no_warn_undefined, CPub.RDFCase.EX}
    end
  end
end
