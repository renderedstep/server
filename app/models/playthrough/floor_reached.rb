# A FLOOR ONE GAME HAS REACHED, and the level reaching it raised that game's
# player to. Stage 5 of the dungeon plan, levelling stage 1.
#
# WRITTEN BY THE ENGINE AND BY NOTHING HERE. The first time a game stands on a
# floor (`Floor`), or in a room laid out inside one, the engine writes this
# game's row for it (renderedstep/engine `turn.rs` `reach_floor`), once:
# `arrived_at` is the story time it was reached, and `level` is one past the
# level the game had when the floor says `levels_up` and the player has a stat
# block, capped at `Character::LEVELS.max`, or nil for a floor that raised
# nothing. On the same turn the engine heals the player to the new maximum. The
# turn's scene claims the row (`scene_id`), the way it claims a toll, and the
# log entry shows `#to_s` from there.
#
# THE LEVEL IS THE GAME'S. `characters.level` is the world's and no floor
# writes it (`Character#advance!` stays uncalled); two games of one world hold
# their own levels side by side. `Playthrough#level_for` is the one reader of
# the level a game's player has, and every max-HP reader on a game asks
# `Playthrough#max_hp_for`.
#
# NO MODEL IS TOLD. The notice is the engine's own words, for the player only:
# nothing a request is built from reads this table.
class Playthrough::FloorReached < ApplicationRecord
  self.table_name = "playthrough_floors"

  belongs_to :playthrough
  belongs_to :location
  belongs_to :scene, optional: true

  validates :arrived_at, presence: true
  validates :level, inclusion: { in: Character::LEVELS }, allow_nil: true
  validates :location_id, uniqueness: { scope: :playthrough_id }

  # THE NOTICE, word for word the engine's `Game::floor_to_s`: "Reaching The
  # Second Floor raised Odile to level 5: 28 hit points, and healed to full."
  # Nil for a floor that raised nothing, and for a game with no player body to
  # count hit points on.
  def to_s
    player = playthrough.character
    return nil if level.nil? || player&.hit_die.nil?

    "Reaching #{location.name} raised #{player.fullname} to level #{level}: " \
      "#{Character.hit_points(level, player.hit_die)} hit points, and healed to full."
  end
end
