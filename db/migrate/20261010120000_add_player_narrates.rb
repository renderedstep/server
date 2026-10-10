# A GAME THE PLAYER NARRATES: the game picks the protagonist's act and tells it
# in the engine's own words, and the player writes the paragraph. `Playthrough`
# has the mode and `Playthrough::Paragraph` the paragraph; what belongs here is
# why the columns have the shape they have.
#
# THE ENGINE'S MIGRATION, TO THE BYTE. The Rust engine plays every turn and
# checks the schema it opens against the one it was written for
# (`RenderedStep::SCHEMA_VERSION`, and the shape of every table it touches),
# so its version and columns are the engine's (renderedstep/engine, "Schema:
# migration 20261010120000"), generated and then given that version. A column
# added here alone would make the engine refuse every turn.
#
# `mode` IS A CLOSED SET WITH A DEFAULT, so every game that exists stays
# narrated and nothing is backfilled: a new parameter ships inert.
#
# THE PARAGRAPH IS KEPT BESIDE THE SCENE, NEVER IN IT. The scene keeps the
# engine's account of the turn and the paragraph table the player's, so both
# survive; `author` leaves room for a narrator's paragraph for the same scene
# later, and one per author is the unique index. `audit` is what
# `Story::Audit`'s checks found in it, written by this app; the engine clears
# it when the paragraph is rewritten and never reads it.
#
# WHO WROTE IT is the game's player (`playthroughs.player_id`), so the row does
# not repeat it, and there is no consent column: nothing is captured from a
# paragraph yet, and the column belongs with whatever first does.
class AddPlayerNarrates < ActiveRecord::Migration[8.1]
  def change
    add_column :playthroughs, :mode, :string, null: false, default: "narrated"
    create_table :playthrough_paragraphs do |t|
      t.references :playthrough, null: false, foreign_key: true
      t.references :scene, null: false, foreign_key: true, index: false
      t.string :author, null: false, default: "player"
      t.text :text, null: false
      t.json :audit
      t.timestamps
    end
    add_index :playthrough_paragraphs, [ :scene_id, :author ], unique: true
  end
end
