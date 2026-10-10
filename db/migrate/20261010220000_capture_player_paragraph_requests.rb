# WHAT A PLAYER'S PARAGRAPH STANDS IN FOR, AND WHAT IT MAY BE USED FOR: the
# request a narrator would have been sent for the turn, built by the engine
# and never sent, its prompt digest, and the player's consent. The engine
# writes all three (renderedstep/engine `narrates.rs`); `Playthrough::Paragraph`
# says what reads them. What belongs here is why the columns have the shape
# they have.
#
# THE ENGINE'S MIGRATION, TO THE BYTE. The Rust engine checks the schema it
# opens against the one it was written for (`RenderedStep::SCHEMA_VERSION`, and
# the shape of every table it touches), so its version and columns are the
# engine's (renderedstep/engine, "The migration the server needs",
# 20261010220000), generated and then given that version, the columns in its
# order. A column added here alone would make the engine refuse every turn.
#
# `consent` IS A CLOSED SET WITH A DEFAULT THAT SHARES NOTHING. Every paragraph
# that exists is `none`, kept for its game alone, and nothing is backfilled:
# the owner's paragraphs written before this are not swept into a set they
# were never written for. `requests` and `prompt_digest` are nullable for the
# same reason -- a turn played before the engine built the request has none.
#
# NO `player_id`. Whose a paragraph is stays the game's player, read through
# `playthrough_id`, as it already is.
class CapturePlayerParagraphRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :playthrough_paragraphs, :consent, :string, null: false, default: "none"
    add_column :playthrough_paragraphs, :requests, :json
    add_column :playthrough_paragraphs, :prompt_digest, :string
  end
end
