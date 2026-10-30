# A REST ONE GAME TOOK (`playthrough_rests`): a `wait` in a safe room
# (`locations.sanctuary`) with no foe in it takes an hour and mends one
# healing thing's worth of hit points, and the engine keeps a row for it so
# the turn's scene can show the notice. Per game, never the world's; a world
# with no safe room never writes one.
#
# THE VERSION AND THE DECLARATION ARE THE ENGINE'S, not ones `bin/rails
# generate migration` stamped. renderedstep/engine#100 applied this migration
# to every world dump in its `parity/worlds/`, version row included, and its
# store holds every fact of the table as declared here
# (`store::OPTIONAL_SHAPES`): a different version or declaration would make
# those dumps disagree with a database this repository migrates.
class CreatePlaythroughRests < ActiveRecord::Migration[8.1]
  def change
    create_table :playthrough_rests do |t|
      t.references :playthrough, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.integer :recovered, null: false
      t.integer :hp_after, null: false
      t.datetime :story_timestamp, null: false
      t.references :scene, foreign_key: true
      t.timestamps
    end
  end
end
