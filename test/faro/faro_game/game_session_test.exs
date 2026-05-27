defmodule Faro.FaroGame.GameSessionTest do
  use Faro.DataCase, async: true

  alias Faro.FaroGame

  describe "create_session/1" do
    test "creates an active session with defaults" do
      assert {:ok, session} = FaroGame.create_session(%{})
      assert session.status == :active
      assert session.id != nil
      assert session.inserted_at != nil
    end
  end

  describe "get_session/1" do
    test "reads back a created session by id" do
      {:ok, created} = FaroGame.create_session(%{})
      assert {:ok, fetched} = FaroGame.get_session(created.id)
      assert fetched.id == created.id
      assert fetched.status == :active
    end

    test "returns error for unknown id" do
      assert {:error, _} = FaroGame.get_session(Ecto.UUID.generate())
    end
  end

  describe "update_session/2" do
    test "transitions status to completed" do
      {:ok, session} = FaroGame.create_session(%{})
      assert {:ok, updated} = FaroGame.update_session(session, %{status: :completed})
      assert updated.status == :completed
    end
  end
end
