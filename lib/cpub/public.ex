# SPDX-FileCopyrightText: 2020-2022 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Public do
  alias CPub.NS.ActivityStreams, as: AS

  @moduledoc """
  The public inbox of the CPub instance.
  """

  @doc """
  Deliver a new message to the public inbox.
  """
  @spec deliver(any) :: :ok | {:error, any}
  def deliver(%ERIS.ReadCapability{} = message) do
    CPub.DB.Set.add(AS.Public, message)
  end

  @doc """
  Get the publix inbox.
  """
  @spec get() :: {:ok, MapSet.t()} | {:error, any}
  def get() do
    CPub.DB.Set.state(AS.Public)
  end
end
