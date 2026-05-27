defmodule Faro.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FaroWeb.Telemetry,
      Faro.Repo,
      {DNSCluster, query: Application.get_env(:faro, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Faro.PubSub},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:faro, :ash_domains),
         Application.fetch_env!(:faro, Oban)
       )},
      FaroWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Faro.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FaroWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
