# GIVE EVERY STORED ROOM THAT STANDS ON ITS OWN A LAYOUT.
#
# A room with no place around it -- a street, a field, a one-room shop -- is
# now read in a plane of its own: a box at its own origin, sized from its sort
# (`Location::Box`, the engine's `layout.rs`). A room written from now on is
# given one when it is realized (`Location::Generator#own_box!`); a room
# already stored has none, and this is where it gets one, with a spot for
# each of the world's own loose things and people in it. The rule is the
# engine's, so the work is too: `Playthrough::RustEngine.lay_out_rooms`, one
# transaction per story, no model call.
#
# THE CHECKED-IN WORLDS TOO, by the same rule: a hand-made world stays in
# step with how a world is generated. Loading one from its seed lays it out
# the same way (`WorldSeed::Loader#lay_out_rooms!`), every roll seeded on the
# story and the row, so a fresh seed and a database brought up here agree.
#
# AFTER THE ONE-ROOM FOLDS, so a place folded back into its room is laid out
# as the room it now is; BEFORE THE SAFE REPAIRS AND THE DOCTOR, so they read
# the laid-out world.
#
# IDEMPOTENT: a room laid out has a box, so a second run finds nothing.
class Update::Steps::LayOutRooms < Update::Step
  def self.key = :lay_out_rooms
  def self.reason = "give every stored room that stands on its own a layout, sized from its sort"

  def call
    lines = stories.filter_map do |story|
      rooms = Playthrough::RustEngine.lay_out_rooms(story, dry_run: dry_run?)
      next if rooms.empty?

      "#{story.title}: #{dry_run? ? "would lay out" : "laid out"} #{rooms.size} " \
        "room#{"s" unless rooms.one?} (#{rooms.map { |room| room.fetch("name") }.join(", ")})"
    end

    report(changed: lines.any?, lines: lines)
  end
end
