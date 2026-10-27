# WHO HAS TO BE WITH YOU FOR A BEAT TO COUNT. The engine reads it
# (renderedstep/engine `Mechanics::beat_reached`); what belongs here is why
# the column has the shape it has.
#
# THE ENGINE'S MIGRATION, TO THE BYTE. The Rust engine checks the schema it
# opens against the one it was written for (`RenderedStep::SCHEMA_VERSION`, and
# the shape of every table it touches), so its version and column are the
# engine's. A column added here alone would make the engine refuse every turn.
#
# `companion_id` IS THE WORLD'S ROW, a character of the step's own story, named
# by `fullname` in a seed file's `companion:`. A step that names one is met only
# when its own trigger is and that person is with the player: in the room,
# alive, following, and not a foe -- `Playthrough#followers`, the one record of
# "with you" the game already keeps.
#
# NULLABLE AND NOT BACKFILLED, and no foreign key, as `quest_outcomes.character`
# has none. Nil plays exactly as before, so every arc that exists, and every
# game in one, plays and replays as it did.
class AddCompanionToQuestSteps < ActiveRecord::Migration[8.1]
  def change
    add_reference :quest_steps, :companion, foreign_key: false
  end
end
