defmodule FaroWeb.PageControllerTest do
  use FaroWeb.ConnCase

  test "GET / renders the home page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Faro"
  end

  test "GET /play renders the play page", %{conn: conn} do
    conn = get(conn, ~p"/play")
    assert html_response(conn, 200) =~ "Casekeeper"
  end

  test "GET /rules renders the rules page", %{conn: conn} do
    conn = get(conn, ~p"/rules")
    assert html_response(conn, 200) =~ "Rules of Faro"
  end

  test "GET /fairness renders the fairness page", %{conn: conn} do
    conn = get(conn, ~p"/fairness")
    assert html_response(conn, 200) =~ "Provably Fair"
  end

  test "GET /philosophy renders the philosophy page", %{conn: conn} do
    conn = get(conn, ~p"/philosophy")
    assert html_response(conn, 200) =~ "Philosophy"
  end
end
