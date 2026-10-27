# MARK EVERY STORED THING A BODY CAN WEAR WITH WHERE IT IS WORN.
#
# A thing is now read as a garment by its name when it is born: the kits'
# `wear` table, matched on the whole name or on its last word, one or several
# of it ("a tattered wool coat", "gloves"), and never on a name that joins
# things ("box of gloves"). A thing stored before that names no place on a
# body, so the slash menu offers nobody `/wear` or `/remove` for it; this is
# where it gets one. The rule is the engine's (`wear::place_for`), so the work
# is too: `Playthrough::RustEngine.mark_wearable`, one transaction per story,
# no model call.
#
# EVERY STORY, SEEDED OR GENERATED, in the world and in each of its games: a
# hand-made world stays in step with how a generated one is marked.
#
# BEFORE THE SAFE REPAIRS AND THE DOCTOR, so they read the marked world.
#
# IDEMPOTENT: a marked thing names its place, so a second run finds nothing.
class Update::Steps::MarkWearable < Update::Step
  def self.key = :mark_wearable
  def self.reason = "mark every stored thing whose name is a garment with the place on a body it is worn on"

  def call
    lines = stories.filter_map do |story|
      items = Playthrough::RustEngine.mark_wearable(story, dry_run: dry_run?)
      next if items.empty?

      "#{story.title}: #{dry_run? ? "would mark" : "marked"} #{items.size} " \
        "thing#{"s" unless items.one?} wearable " \
        "(#{items.map { |item| "##{item.fetch("id")} #{item.fetch("name")} on the #{item.fetch("wear")}" }.join(", ")})"
    end

    report(changed: lines.any?, lines: lines)
  end
end
