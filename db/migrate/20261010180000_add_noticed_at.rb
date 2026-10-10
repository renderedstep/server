# WHAT A GAME THE PLAYER NARRATES HAS NOTICED of the rooms it stands in: a
# story-time stamp on this game's copy of each thing and on its state for a
# person. The engine writes and reads it (renderedstep/engine `noticed.rs`);
# what belongs here is why the columns have the shape they have.
#
# THE ENGINE'S MIGRATION, TO THE BYTE. The Rust engine checks the schema it
# opens against the one it was written for (`RenderedStep::SCHEMA_VERSION`, and
# the shape of every table it touches), so its version and columns are the
# engine's (renderedstep/engine, "Schema: migration 20261010180000"), generated
# and then given that version. A column added here alone would make the engine
# refuse every turn.
#
# NULLABLE AND NOT BACKFILLED. Only a game the player narrates is ever stamped,
# so every row that exists stays unstamped and every game that exists plays as
# it did: a new parameter ships inert. It is on the game's layer only -- a
# world's own row is never noticed, and `Item::NOT_COPIED` keeps a copy from
# carrying one off its template.
class AddNoticedAt < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :noticed_at, :datetime
    add_column :playthrough_npc_states, :noticed_at, :datetime
  end
end
