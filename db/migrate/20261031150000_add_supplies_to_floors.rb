# A FLOOR'S SUPPLIES (`floors.safe_rooms`, `floors.healing_count`,
# `healing_name`, `healing_description`), the room the engine lays out safe
# (`locations.sanctuary`) and the thing it leaves lying in one
# (`items.supply`): a floor that names supplies is stocked when it is laid
# out, once, for the world, and never again. A safe room is laid out `safe`,
# with no hazard and nobody born in it; a healing thing is a world row with
# the supply marker and no `kit_key`. A world with none of the keys lays out
# as before.
#
# THE VERSION AND THE DECLARATION ARE THE ENGINE'S, not ones `bin/rails
# generate migration` stamped. renderedstep/engine#99 applied this migration
# to every world dump in its `parity/worlds/`, version row included, and its
# store holds all six facts as declared here (`store::OPTIONAL_COLUMNS`): a
# different version or declaration would make those dumps disagree with a
# database this repository migrates.
class AddSuppliesToFloors < ActiveRecord::Migration[8.1]
  def change
    add_column :floors, :safe_rooms, :integer, default: 0, null: false
    add_column :floors, :healing_count, :integer, default: 0, null: false
    add_column :floors, :healing_name, :string
    add_column :floors, :healing_description, :text
    add_column :locations, :sanctuary, :boolean, default: false, null: false
    add_column :items, :supply, :string
  end
end
