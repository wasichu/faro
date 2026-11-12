defmodule Faro.Repo.Migrations.HardenGameIntegrity do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION ash_required(value ANYCOMPATIBLE, payload jsonb)
    RETURNS ANYCOMPATIBLE AS $$
    BEGIN
      IF value IS NULL THEN
        RAISE EXCEPTION 'ash_error: %', payload::text;
      END IF;

      RETURN value;
    END;
    $$ LANGUAGE plpgsql
    STABLE
    SET search_path = '';
    """)

    create unique_index(:game_turns, [:round_id, :index],
             name: "game_turns_unique_round_turn_index"
           )

    create unique_index(:wallets, [:game_session_id], name: "wallets_unique_session_index")
  end

  def down do
    drop_if_exists unique_index(:wallets, [:game_session_id],
                     name: "wallets_unique_session_index"
                   )

    drop_if_exists unique_index(:game_turns, [:round_id, :index],
                     name: "game_turns_unique_round_turn_index"
                   )

    # ash_required/2 was redefined in place for ash-functions v7; keep it on rollback.
  end
end
