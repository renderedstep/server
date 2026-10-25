# THE ENDING A GAME HAS EARNED AND NOT YET TAKEN. The engine writes and reads
# it (renderedstep/engine `turn.rs`, `glance.rs`); what belongs here is why the
# table has the shape it has.
#
# THE ENGINE'S MIGRATION, TO THE BYTE. The Rust engine checks the schema it
# opens against the one it was written for (`RenderedStep::SCHEMA_VERSION`, and
# the shape of every table it touches), so its version and columns are the
# engine's (renderedstep/engine, "What the server PR must change"). A table
# shaped differently here would make the engine refuse every turn.
#
# A ROW OF ITS OWN, NOT A COLUMN ON `playthrough_endings`. An ending row means
# "the story concluded" everywhere it is read; a due row means the line that met
# the last beat fixed which ending `/end` will write, so nothing played after it
# can change that. One per game, and `declined_at` is "Not yet".
class CreatePlaythroughDueEndings < ActiveRecord::Migration[8.1]
  def change
    create_table :playthrough_due_endings do |t|
      t.references :playthrough, null: false, foreign_key: true, index: { unique: true }
      t.references :quest_outcome, null: false, foreign_key: true
      t.datetime :due_at, null: false
      t.datetime :declined_at
      t.timestamps
    end
  end
end
