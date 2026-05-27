defmodule Faro.FaroGame.GameSessionTest do
  use Faro.DataCase, async: true

  alias Faro.FaroGame.GameSession

  describe "create/1" do
    test "creates an active session with defaults" do
      assert {:ok, session} = GameSession.create(%{})
      assert session.status == :active
      assert session.id != nil
      assert session.inserted_at != nil
    end
  end

  describe "get/1" do
    test "reads back a created session by id" do
      {:ok, created} = GameSession.create(%{})
      assert {:ok, fetched} = GameSession.get(created.id)
      assert fetched.id == created.id
      assert fetched.status == :active
    end

    test "returns error for unknown id" do
      assert {:error, _} = GameSession.get(Ecto.UUID.generate())
    end
  end

  describe "update/2" do
    test "transitions status to completed" do
      {:ok, session} = GameSession.create(%{})
      assert {:ok, updated} = GameSession.update(session, %{status: :completed})
      assert updated.status == :completed
    end
  end
end
