defmodule QlikElixir.AdvisoryExceptionsTest do
  use ExUnit.Case, async: true

  # `mix hex.audit` exceptions live in `mix.exs` (`advisory_exceptions/0`) with an
  # expiry date. A lapsed exception fails the suite: upgrade the package and drop
  # it, or renew it with a fresh reason and date.
  test "no security advisory exception has expired" do
    today = Date.utc_today()

    for %{id: id, package: package, until: until, reason: reason} <-
          Mix.Project.get!().advisory_exceptions() do
      assert is_binary(reason) and reason != ""

      refute Date.after?(today, until),
             "Exception #{id} (#{package}) expired on #{until}. Upgrade #{package} and " <>
               "remove it from advisory_exceptions/0 in mix.exs, or renew it with a reason."
    end
  end
end
