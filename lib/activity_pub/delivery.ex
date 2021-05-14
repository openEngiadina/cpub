# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.ActivityPub.Delivery do
  @moduledoc """
  Implements strategies for delivering ActivityPub messages.
  """

  alias CPub.User

  @spec deliver(RDF.IRI.t() | [RDF.IRI.t()], ERIS.ReadCapability.t()) ::
          %{required(RDF.IRI.t()) => {:ok, :local} | {:error, atom}}
  def deliver(recipients, %ERIS.ReadCapability{} = message) when is_list(recipients) do
    ## TODO: analyze for which recipients message could be delivered to their shared inbox
    Map.new(recipients, &{&1, deliver(&1, message)})
  end

  def deliver(%RDF.IRI{} = recipient, %ERIS.ReadCapability{} = message) do
    case RDF.IRI.to_string(recipient) do
      "local:" <> username ->
        deliver_local(username, message)

      _ ->
        {:error, :no_delivery_method}
    end
  end

  @spec deliver_local(String.t(), ERIS.ReadCapability.t()) :: {:ok, :local}
  defp deliver_local(username, message) do
    with {:ok, user} <- User.get(username),
         :ok <- User.Inbox.put(user, message) do
      {:ok, :local}
    end
  end
end
