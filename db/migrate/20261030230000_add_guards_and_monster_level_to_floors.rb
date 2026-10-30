# WHO STANDS ON A FLOOR: the level everybody the engine births there is born
# at (`floors.monster_level`), and the guards a world posts to it
# (`characters.posted_to_id`), whom the engine stands in the floor's way-down
# room when it lays the floor out -- once, for the world (VISION.md principle
# 7). A floor with neither plays as before.
#
# THE VERSION AND THE DECLARATION ARE THE ENGINE'S, not ones `bin/rails
# generate migration` stamped. renderedstep/engine#95 applied this migration
# to every world dump in its `parity/worlds/`, version row included, and its
# store holds every fact of it as declared here (`store::OPTIONAL_COLUMNS`):
# a different version or declaration would make those dumps disagree with a
# database this repository migrates.
class AddGuardsAndMonsterLevelToFloors < ActiveRecord::Migration[8.1]
  def change
    add_column :floors, :monster_level, :integer
    add_reference :characters, :posted_to, foreign_key: { to_table: :locations, on_delete: :nullify }
  end
end
