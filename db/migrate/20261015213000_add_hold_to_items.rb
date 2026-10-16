# HOW HARD A PART HOLDS TO THE FIXED PIECE IT IS ATTACHED TO, on both item
# layers. The engine writes and reads it (renderedstep/engine `turn/snap.rs`);
# what belongs here is why the column has the shape it has.
#
# THE ENGINE'S MIGRATION, TO THE BYTE. The Rust engine checks the schema it
# opens against the one it was written for (`RenderedStep::SCHEMA_VERSION`, and
# the shape of every table it touches), so its version and column are the
# engine's (renderedstep/engine, "Server migration"), generated and then given
# that version. A column added here alone would make the engine refuse every
# turn.
#
# ONE OF `Item::Kit::HOLD_PENALTY`'s KEYS ON A PART, NOTHING ON ANY OTHER ROW.
# A game's copy of a part brings its hold along (`Item::Snapshot` copies every
# column `Item::NOT_COPIED` does not name), and a part that comes away in the
# hand is a portable thing again with its hold cleared.
#
# NULLABLE AND NOT BACKFILLED. No row that exists is a part: every world that
# exists plays as it did, and parts arrive only with a room furnished from now
# on. A new parameter ships inert.
class AddHoldToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :hold, :string
  end
end
