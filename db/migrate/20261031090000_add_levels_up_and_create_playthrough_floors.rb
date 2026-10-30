# A FLOOR THAT RAISES A LEVEL (`floors.levels_up`), and every floor a game has
# reached (`playthrough_floors`): one row per game and floor, written once by
# the engine the first time that game stands on it, carrying the level the
# floor raised the game's player to, or nil for a floor that raised nothing.
# The level is the game's; `characters.level` is the world's and never moves.
# A world with no `levels_up` plays as before.
#
# THE VERSION AND THE DECLARATION ARE THE ENGINE'S, not ones `bin/rails
# generate migration` stamped. renderedstep/engine#97 applied this migration
# to every world dump in its `parity/worlds/`, version row included, and its
# store holds every fact of it as declared here (`store::OPTIONAL_COLUMNS`,
# `store::OPTIONAL_SHAPES`): a different version or declaration would make
# those dumps disagree with a database this repository migrates.
class AddLevelsUpAndCreatePlaythroughFloors < ActiveRecord::Migration[8.1]
  def change
    add_column :floors, :levels_up, :boolean, default: false, null: false
    create_table :playthrough_floors do |t|
      t.references :playthrough, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.datetime :arrived_at, null: false
      t.integer :level
      t.references :scene, foreign_key: true
      t.timestamps
    end
    add_index :playthrough_floors, [ :playthrough_id, :location_id ], unique: true,
      name: "index_playthrough_floors_on_playthrough_and_location"
  end
end
