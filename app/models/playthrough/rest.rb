# A REST ONE GAME TOOK. Stage 8 of the dungeon plan.
#
# WRITTEN BY THE ENGINE AND BY NOTHING HERE. A `wait` is a rest when the room
# is a safe room (`locations.sanctuary`), nobody in it is a foe, and the player
# is alive with a stat block: it mends one healing thing's worth of hit points,
# up to the game's maximum, and on the told path its scene spends an hour
# instead of five minutes (renderedstep/engine `turn.rs` `REST`, `rest`). The
# engine writes this game's row for it: `recovered` is what it mended (0 for a
# rest at full, which is still a rest), `hp_after` what the player then had,
# and `story_timestamp` the story time the rest BEGAN. The turn's scene claims
# the row (`scene_id`), the way it claims a toll, and the log entry shows
# `#to_s` from there. A rest is never refused, even past a floor's countdown;
# the player then falls with the floor and the row is kept.
#
# NO MODEL IS TOLD. The notice is the engine's own words, for the player only:
# nothing a request is built from reads this table, and the narrator is asked
# about a rest exactly as about any wait.
class Playthrough::Rest < ApplicationRecord
  self.table_name = "playthrough_rests"

  belongs_to :playthrough
  belongs_to :location
  belongs_to :scene, optional: true

  validates :recovered, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :hp_after, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :story_timestamp, presence: true

  # THE NOTICE, word for word the engine's `Game::rest_to_s`: "Odile rested for
  # an hour in The Landing and recovered 8 hit points (14 of 18)." The maximum
  # is the game's at the rest's own time, as a toll's is. "an hour" is fixed
  # copy, not built from the engine's `REST.minutes`. Nil for a game with no
  # player body to count hit points on.
  def to_s
    player = playthrough.character
    return nil if player.nil? || !player.stat_block?

    max = playthrough.max_hp_for(player, at: story_timestamp)
    "#{player.fullname} rested for an hour in #{location.name} and recovered " \
      "#{recovered} hit point#{"s" unless recovered == 1} (#{hp_after} of #{max})."
  end
end
