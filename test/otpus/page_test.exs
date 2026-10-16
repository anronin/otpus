defmodule OtpusTest.PageTest do
  use ExUnit.Case, async: true

  test "every id the page references exists in the markup" do
    page = File.read!(Application.app_dir(:otpus, "priv/index.html"))

    defined = scan(page, ~r/\sid="([^"]+)"/)

    referenced =
      page
      |> scan(~r/\$\('([^']+)'\)/)
      |> MapSet.union(scan(page, ~r/\s(?:for|aria-controls|aria-describedby)="([^"]+)"/))

    assert MapSet.size(referenced) > 0
    assert MapSet.difference(referenced, defined) == MapSet.new()
  end

  defp scan(page, regex) do
    regex
    |> Regex.scan(page, capture: :all_but_first)
    |> List.flatten()
    |> MapSet.new()
  end
end
