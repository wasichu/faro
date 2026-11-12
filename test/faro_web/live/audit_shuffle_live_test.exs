defmodule FaroWeb.AuditShuffleLiveTest do
  use FaroWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "submit verifies the submitted fields without a prior change event", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/audit/shuffle")
    seed = :binary.copy(<<42>>, 32)

    view
    |> form("#shuffle-verifier-form", %{
      server_seed: Base.encode16(seed),
      server_seed_hash: Faro.GameEngine.Fairness.commit_server_seed(seed),
      client_seed: " spaced seed ",
      nonce: "1"
    })
    |> render_submit()

    assert has_element?(view, "#verification-result")
    refute has_element?(view, "#verification-error")
  end

  test "rejects nonce overflow and incorrectly sized seeds without crashing", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/audit/shuffle")

    for values <- [
          %{server_seed: String.duplicate("00", 32), nonce: "18446744073709551616"},
          %{server_seed: "00", nonce: "1"}
        ] do
      view |> form("#shuffle-verifier-form", values) |> render_submit()
      assert has_element?(view, "#verification-error")
      refute has_element?(view, "#verification-result")
    end
  end

  test "malformed query values do not crash mount", %{conn: conn} do
    {:ok, view, _} = live(conn, "/audit/shuffle?server_seed[]=invalid&nonce[]=invalid")
    assert has_element?(view, "#shuffle-verifier-form")
  end
end
