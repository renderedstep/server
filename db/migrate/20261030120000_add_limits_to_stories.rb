# A STORY'S OWN LIMITS on how many people and how many things its world may
# hold. A world file names them (`story.limits.people` / `.things`,
# `WorldSeed::Loader`); where it names none the columns are null and the
# ordinary limits hold (`Character::Registry::MAX_PER_STORY`,
# `Item::Registry::MAX_PER_STORY`), so every stored story plays as before.
#
# THE VERSION IS THE ENGINE'S, not one `bin/rails generate migration` stamped.
# renderedstep/engine#90 applied this migration to every world dump in its
# `parity/worlds/`, version row included, and its store reads the two columns
# exactly as declared here (`store::OPTIONAL_COLUMNS`): nullable, no default,
# people first. A different version or declaration would make those dumps
# disagree with a database this repository migrates.
class AddLimitsToStories < ActiveRecord::Migration[8.1]
  def change
    add_column :stories, :people_limit, :integer
    add_column :stories, :things_limit, :integer
  end
end
