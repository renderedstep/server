# A FLOOR: A PLACE ITS WORLD GIVES A ROOM COUNT, laid out by the engine as
# exactly that many rooms on one storey (the engine's `floor.rs`), with a way
# down rolled onto a room that is never the entry. Stage 2 of the dungeon
# plan; a place with no row is laid out by `Location::Interior` as it always
# was, so every stored story plays as before.
#
# LAID OUT ONCE, THE FIRST TIME ANYBODY REACHES IT, and then left alone -- VISION
# principle 7. Every later game in the world reads the stored rooms. So this
# row is a PARAMETER OF THE LAYOUT and not a description of it: a re-seed that
# changes `rooms` after the floor has rooms changes the row only, and
# `rake game:doctor` reports the difference (`floor_laid_out_to_another_count`)
# rather than anything re-laying the floor.
#
# A WORLD SUPPLIES PARAMETERS, NEVER BEHAVIOUR (AGENTS.md). `danger` and
# `hazard` are words of `Location::Parameters`' own tables, the ones a place
# call picks from, and what each does to a room is that table's; `down_location`
# names the floor below, whose doorway the engine opens onto the way-down room.
# The model's picks for a floor are never read.
#
# WHO WRITES IT: `WorldSeed::Loader`, from a location's `floor:` key, and
# nothing else. `WorldSeed::Exporter` writes the key back.
class Floor < ApplicationRecord
  # THE MOST ROOMS A FLOOR IS LAID OUT WITH, the engine's `floor::MOST_ROOMS`.
  MOST_ROOMS = 1000

  # THE PACES A SIDE OF A FLOOR'S ROOM IS GIVEN ON AVERAGE when its footprint
  # is sized from its room count, the engine's `floor::ROOM_SIDE`.
  ROOM_SIDE = 6

  belongs_to :location
  belongs_to :down_location, class_name: "Location", optional: true

  validates :location_id, uniqueness: true
  validates :rooms, numericality: { only_integer: true, in: 1..MOST_ROOMS }
  validates :rooms, numericality: { greater_than_or_equal_to: 2, message: "must be at least 2 with a way down, which is never the entry" },
                    if: :down_location_id?
  validates :danger, inclusion: { in: Location::Parameters::DANGER.keys }, allow_nil: true
  validates :hazard, inclusion: { in: Location::Parameters::HAZARDS }, allow_nil: true
  # THE LEVEL EVERYBODY THE ENGINE BIRTHS ON THIS FLOOR IS BORN AT, in it or in
  # a room of it (renderedstep/engine `realize.rs` `admit_new`, and
  # `Character::Registry` here). Their hit die and abilities are rolled as
  # anybody's are; only the level is the floor's. Nil is the ordinary
  # `Character::StatBlock::STARTING_LEVEL`.
  validates :monster_level, inclusion: { in: Character::LEVELS }, allow_nil: true
  # WHETHER REACHING THIS FLOOR RAISES A GAME'S LEVEL: once a game, by one, and
  # healed to full on the same turn (the engine's `turn.rs` `reach_floor`). The
  # level is the game's (`Playthrough::FloorReached`), never the world's.
  validates :levels_up, inclusion: { in: [ true, false ] }
  validate :a_way_down_is_another_floor_of_this_story

  # HOW MANY ROOMS A FLOOR OF `rooms` IS DRAWN WITH: at least one, at least two
  # with a way down, and at most `MOST_ROOMS` -- the engine's
  # `floor::room_count`, so a count outside the validation above (a row raw SQL
  # wrote) is still read as the engine reads it.
  def self.room_count(rooms, down: false) = rooms.to_i.clamp(down ? 2 : 1, MOST_ROOMS)

  # `[columns, rows]` OF THE GRID A FLOOR OF `rooms` ROOMS IS CUT INTO: as square
  # as it goes, the last line short when the count is not a product. The
  # engine's `floor::grid`.
  def self.grid(rooms)
    rooms = [ rooms, 1 ].max
    columns = Integer.sqrt(rooms)
    columns += 1 if columns * columns < rooms
    [ columns, rooms.ceildiv(columns) ]
  end

  # THE FOOTPRINT `[width, depth]` A FLOOR OF `rooms` ROOMS IS SIZED AT, which
  # `WorldSeed::Loader` writes so the floor is a place (`Location#place?`)
  # before anybody walks into it. The engine's `floor::footprint`.
  def self.footprint(rooms) = grid(rooms).map { |side| side * ROOM_SIDE }

  # The count this floor is laid out to, as the engine reads it.
  def room_count = self.class.room_count(rooms, down: down_location_id.present?)

  def footprint = self.class.footprint(room_count)

  private

  def a_way_down_is_another_floor_of_this_story
    return if down_location.nil?

    if down_location_id == location_id
      errors.add(:down_location, "is this floor itself")
    elsif location && down_location.story_id != location.story_id
      errors.add(:down_location, "is in another story")
    elsif down_location.floor.nil?
      errors.add(:down_location, "is not a floor")
    end
  end
end
