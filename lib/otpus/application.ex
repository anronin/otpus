defmodule Otpus.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Bandit, plug: Otpus.Router, ip: :loopback, port: port()}
    ]

    IO.puts("Otpus listening on http://localhost:#{port()}")
    Supervisor.start_link(children, strategy: :one_for_one, name: Otpus.Supervisor)
  end

  defp port, do: Application.fetch_env!(:otpus, :port)
end
