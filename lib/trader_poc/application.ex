defmodule TraderPoc.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TraderPocWeb.Telemetry,
      TraderPoc.Repo,
      {Oban, Application.fetch_env!(:trader_poc, Oban)},
      {DNSCluster, query: Application.get_env(:trader_poc, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TraderPoc.PubSub},
      TraderPocWeb.Presence,
      # Start a worker by calling: TraderPoc.Worker.start_link(arg)
      # {TraderPoc.Worker, arg},
      # Start to serve requests, typically the last entry
      TraderPocWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TraderPoc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TraderPocWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
