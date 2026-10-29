# ONE FREE-TYPED LINE THE LOCAL READER'S READING REFUSED, KEPT TO LEARN FROM.
#
# THE OWNER'S RULING, 2026-10-29, in his words: *"always refuse and ask, we
# should track refusals so we can try to improve the model with them in the
# future"*. So when the local reader is unsure, the game refuses and asks
# (`Playthrough::Refusal`'s `:unsure`), and every line its reading refuses is
# kept here: the reader is retrained on lines it could not read, and those are
# exactly the lines a played game throws away.
#
# THE ENGINE WRITES IT, AND NOTHING HERE DOES. Only the engine holds what the
# reader was shown and everything it answered, so the row is written in the
# turn's own transaction, beside the drift or overreach row
# (renderedstep/engine `keep_refusal`). This class is for reading, labelling
# and deleting rows.
#
# WHAT A ROW IS. Enough to relabel and train on with no game behind it:
#   typed              the line, verbatim
#   state              the reader's request state, the room's lists by name
#   answers            the reader's whole reply, every probability (null when
#                      it never answered: a throw, a put-on, the reader down)
#   reading            what it read, by name: action, target, also_named,
#                      resolved_by
#   act_confidence,    how sure it was of the act, and of the thing for that
#   thing_confidence   act (null where the act took no thing)
#   refusal            what the player was shown, as `playthrough_commands`
#                      keeps it
#   weights            the reader's weights digest (`PointerClassifierAgent`)
# and empty label slots: `label`, `labelled_at`, `note`, `status`. A refusal
# whose reading was right (`:immovable`, `:cannot_carry`, `:unplayable`) is not
# kept, nor a slash line, which no reader read.
#
# IT OUTLIVES ITS GAME. `playthrough_id` and `location_id` are plain integers
# with no foreign key and no association, so deleting a game leaves its lines
# here; they are for jumping back to the game while it exists.
#
# IT NEVER LEAVES THE MACHINE WITHOUT THE OWNER'S YES. It is the player's own
# words, so it is kept only where `Playthrough::Debug.enabled?` says the person
# at the keyboard is the one building the game (`Playthrough::RustEngine.models`
# asks the engine to keep lines only then); it is never packaged
# (`Playthrough::SqlitePackage::NEVER_PACKAGED`), never in a dump of rows
# (`Playthrough::Requests::SKIPPED`, `EngineVectors::Records::SKIPPED`), and the
# typed line is filtered out of the request log. Sending a row to any model,
# attaching it to an issue, and training weights that will be published each
# need his yes first. A row stays until it is labelled or deleted: nothing
# expires it.
class RefusedLine < ApplicationRecord
  STATUSES = %w[new labelled excluded].freeze

  validates :typed, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :unlabelled, -> { where(status: "new") }
end
