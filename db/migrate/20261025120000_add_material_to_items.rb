# WHAT A THING IS MADE OF, on both item layers: one of `Item::MATERIALS` (the
# engine's `data/item/kits.yml` `materials`), or nothing, which is unknown. The
# engine writes and checks it (renderedstep/engine `material.rs`); what belongs
# here is why the column has the shape it has.
#
# THE ENGINE'S MIGRATION, TO THE BYTE. The Rust engine checks the schema it
# opens against the one it was written for (`RenderedStep::SCHEMA_VERSION`, and
# the shape of every table it touches), so its version and column are the
# engine's, generated and then given that version. A column added here alone
# would make the engine refuse every turn.
#
# NULLABLE AND NOT BACKFILLED. No act reads it yet: every world that exists
# plays as it did, and a material arrives only with a room furnished from now
# on or a seed file that names one. A new parameter ships inert.
class AddMaterialToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :material, :string
  end
end
