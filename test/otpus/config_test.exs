defmodule OtpusTest.ConfigTest do
  use ExUnit.Case, async: false

  setup do
    previous = System.get_env("PORT")
    on_exit(fn -> restore_port(previous) end)
  end

  test "keeps the default port when PORT is not set" do
    System.delete_env("PORT")
    assert runtime_config() == []
  end

  test "uses PORT when it is set" do
    System.put_env("PORT", "8080")
    assert runtime_config() == [otpus: [port: 8080]]
  end

  defp runtime_config, do: Config.Reader.read!("config/runtime.exs", env: :prod)

  defp restore_port(nil), do: System.delete_env("PORT")
  defp restore_port(value), do: System.put_env("PORT", value)
end
