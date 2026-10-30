# A FLOOR: a place its world lays out as exactly `rooms` rooms on one storey,
# the first time anybody reaches it, and then leaves alone (VISION.md
# principle 7). A world file names one with `floor:` (`WorldSeed::Loader`);
# where a place has no row it is laid out as it always was, so every stored
# story plays as before. `danger` and `hazard` are the floor's own words,
# which every room of it is dealt from; `down_location` is the floor below,
# whose doorway the engine opens onto a room that is never the entry.
#
# THE VERSION AND THE DECLARATION ARE THE ENGINE'S, not ones `bin/rails
# generate migration` stamped. renderedstep/engine#94 applied this migration
# to every world dump in its `parity/worlds/`, version row included, and its
# store holds every fact of the table as declared here
# (`store::OPTIONAL_SHAPES`): a different version or declaration would make
# those dumps disagree with a database this repository migrates.
class CreateFloors < ActiveRecord::Migration[8.1]
  def change
    create_table :floors do |t|
      t.references :location, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.integer :rooms, null: false
      t.string :danger
      t.string :hazard
      t.references :down_location, foreign_key: { to_table: :locations, on_delete: :nullify }
      t.timestamps
    end
  end
end
