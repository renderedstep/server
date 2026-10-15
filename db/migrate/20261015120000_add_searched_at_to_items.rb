# WHETHER A FIXED PIECE HAS BEEN SEARCHED, on both item layers. The engine
# writes and reads it (renderedstep/engine `turn/search.rs`); what belongs here
# is why the column has the shape it has.
#
# THE ENGINE'S MIGRATION, TO THE BYTE. The Rust engine checks the schema it
# opens against the one it was written for (`RenderedStep::SCHEMA_VERSION`, and
# the shape of every table it touches), so its version and column are the
# engine's (renderedstep/engine, "Server migration"), generated and then given
# that version. A column added here alone would make the engine refuse every
# turn.
#
# ONE COLUMN, TWO MEANINGS, ONE PER LAYER. On a game's copy of a piece it says
# this game has searched it, so a piece is searched once a game. On the world's
# own piece it says what lies inside has been drawn (`Item::Contents`), so it is
# drawn once for every game. `Item::NOT_COPIED` keeps a copy from inheriting
# the world's stamp: a new game finds the piece unsearched.
#
# NULLABLE AND NOT BACKFILLED. Every row that exists is unsearched, and every
# world that exists plays as it did until somebody searches something: a new
# parameter ships inert.
class AddSearchedAtToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :searched_at, :datetime
  end
end
