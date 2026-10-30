# A FLOOR THAT FALLS (`floors.minutes`), and the story time it fell in one
# game (`playthrough_floors.fell_at`): a floor with `minutes` gives way in a
# game that many story minutes after that game first stood on it
# (`arrived_at`), and a player on it then dies with it. The world's rows are
# never touched, so every other game finds the floor whole. A world with no
# `minutes` plays as before.
#
# THE VERSION AND THE DECLARATION ARE THE ENGINE'S, not ones `bin/rails
# generate migration` stamped. renderedstep/engine#98 applied this migration
# to every world dump in its `parity/worlds/`, version row included, and its
# store holds both facts as declared here (`store::OPTIONAL_COLUMNS`): a
# different version or declaration would make those dumps disagree with a
# database this repository migrates.
class AddMinutesToFloorsAndFellAtToPlaythroughFloors < ActiveRecord::Migration[8.1]
  def change
    add_column :floors, :minutes, :integer
    add_column :playthrough_floors, :fell_at, :datetime
  end
end
