# WHERE ON A BODY A THING IS WORN, AND WHETHER IT IS, on both item layers. The
# engine owns the rules (renderedstep/engine `wear.rs`, and the closed list of
# places in its `data/item/wear.yml`); what belongs here is why the columns
# have the shape they have.
#
# THE ENGINE'S MIGRATION, TO THE BYTE. The Rust engine checks the schema it
# opens against the one it was written for (`RenderedStep::SCHEMA_VERSION`, and
# the shape of every table it touches), so its version and columns are the
# engine's, generated and then given that version. A column added here alone
# would make the engine refuse every turn.
#
# `wear` IS A FACT ABOUT THE THING: one of the places, or null for a thing
# nobody wears, so a game's copy brings it along (`Item::Snapshot` copies every
# column `Item::NOT_COPIED` does not name). `worn` is a kind of carried, never a
# fourth place a thing can be: a worn thing is in the party's hands or a
# person's.
#
# NULLABLE, FALSE, AND NOT BACKFILLED. No row that exists is wearable or worn,
# so every world that exists plays as it did. A new parameter ships inert.
class AddWearAndWornToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :wear, :string
    add_column :items, :worn, :boolean, default: false, null: false
  end
end
