defmodule Elixdo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElixdoWeb.Telemetry,
      Elixdo.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:elixdo, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:elixdo, :dns_cluster_query) || :ignore},
      {Registry, keys: :unique, name: Elixdo.Lists.Registry},
      Elixdo.Lists.Supervisor,
      {Phoenix.PubSub, name: Elixdo.PubSub},
      Elixdo.DateWatcher,
      Elixdo.SearchIndex,
      # Start a worker by calling: Elixdo.Worker.start_link(arg)
      # {Elixdo.Worker, arg},
      # Start to serve requests, typically the last entry
      ElixdoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Elixdo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixdoWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
