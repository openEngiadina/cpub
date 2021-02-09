# SPDX-FileCopyrightText: 2020-2021 pukkamustard <pukkamustard@posteo.net>
# SPDX-FileCopyrightText: 2020-2021 rustra <rustra@disroot.org>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule CPub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias CPub.HTTP.AdapterHelper
  alias CPub.HTTP.Gun
  alias CPub.Web.Endpoint

  require Logger

  @name CPub.MixProject.project()[:name]
  @version CPub.MixProject.project()[:version]
  @repository CPub.MixProject.project()[:source_url]
  @env Mix.env()

  def name, do: @name
  def version, do: @version
  def named_version, do: "#{@name} #{@version}"
  def repository, do: @repository

  @spec start(Application.start_type(), term) ::
          {:ok, pid} | {:ok, pid, Application.state()} | {:error, term}
  def start(_type, _args) do
    children =
      [
        Endpoint,
        CPub.DB
      ] ++
        task_children() ++
        http_children(tesla_adapter(), @env)

    opts = [strategy: :one_for_one, name: CPub.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp task_children do
    [
      %{
        id: :log_app_info,
        start: {Task, :start_link, [&log_application_info/0]},
        restart: :temporary
      }
    ]
  end

  defp http_children(_, :test), do: http_children(Tesla.Adapter.Gun, nil)

  defp http_children(Tesla.Adapter.Gun, _) do
    Gun.ConnectionPool.children() ++
      [{Task, &AdapterHelper.Gun.limiter_setup/0}]
  end

  defp http_children(_, _), do: []

  defp log_application_info do
    Logger.info("Starting #{@name} (#{@version}; #{@repository})")
  end

  defp tesla_adapter do
    adapter = Application.get_env(:tesla, :adapter)

    if adapter == Tesla.Adapter.Gun do
      if version = otp_version() do
        [major, minor] = otp_version_major_minor(version)

        if (major == 22 and minor < 2) or major < 22 do
          raise "
          !!!OTP VERSION WARNING!!!
          You are using gun adapter with OTP version #{version}, which doesn't support correct handling of unordered certificates chains. Please update your Erlang/OTP to at least 22.2.
          "
        end
      else
        raise "
        !!!OTP VERSION WARNING!!!
        To support correct handling of unordered certificates chains - OTP version must be > 22.2.
        "
      end
    end

    adapter
  end

  defp otp_version do
    # OTP Version https://erlang.org/doc/system_principles/versions.html#otp-version
    [
      Path.join(:code.root_dir(), "OTP_VERSION"),
      Path.join([:code.root_dir(), "releases", :erlang.system_info(:otp_release), "OTP_VERSION"])
    ]
    |> otp_version_from_files()
  end

  defp otp_version_from_files([]), do: nil

  defp otp_version_from_files([path | paths]) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> String.replace(~r/\r|\n|\s/, "")
    else
      otp_version_from_files(paths)
    end
  end

  defp otp_version_major_minor(version) do
    version
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> Enum.take(2)
  end

  @spec config_change(keyword, keyword, [atom]) :: :ok
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)

    :ok
  end
end
