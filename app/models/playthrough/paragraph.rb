# WHAT THE PLAYER WROTE FOR ONE TURN OF A GAME THEY NARRATE.
#
# In a game the player narrates (`Playthrough#player_narrates?`) the game picks
# the protagonist's act and tells it in the engine's own words, and the player
# writes the paragraph. This is that paragraph, kept BESIDE the turn's `Scene`
# and never in it: the scene keeps the engine's account and this row the
# player's, so both survive.
#
# PROSE AND NOTHING ELSE. No rule and no prompt reads it. The engine writes the
# row (`Playthrough::Session#write_paragraph!`, through the extension), refuses
# one for a scene the game did not choose, and reads none of it back; a later
# prompt is told the engine's fact for the turn instead. So there is nothing
# here for the engine to guard: the paragraph moves no row.
#
# CHECKED, NEVER ENFORCED. `audit` is what `Story::Audit`'s existing checks
# found when the paragraph was read in the scene's place
# (`Story::Audit.paragraph`), kept as `Note`s and shown to the player beside
# it. A flagged paragraph is kept as written: a player may contradict the facts,
# and saying so is all the game does about it. A rewrite clears the audit (the
# engine does that) and the session checks the new words again.
#
# WHOSE IT IS is the game's player, read through the game; the browser's games
# belong to nobody.
class Playthrough::Paragraph < ApplicationRecord
  self.table_name = "playthrough_paragraphs"

  # WHO WROTE IT. Only the player today; the column is there so a narrator's
  # paragraph for the same scene can sit beside it later.
  AUTHORS = %w[player].freeze

  belongs_to :playthrough, inverse_of: :paragraphs
  belongs_to :scene, inverse_of: :paragraphs
  has_one :player, through: :playthrough

  validates :author, inclusion: { in: AUTHORS }, uniqueness: { scope: :scene_id }
  validates :text, presence: true

  # ONE THING THE CHECK FOUND, in the words the player is shown: the check's
  # code, its headline, and the line of evidence that convicts it.
  Note = Data.define(:code, :headline, :evidence)

  # What the check found, or nil when the paragraph has not been checked.
  def notes
    return nil if audit.nil?

    Array(audit["flags"]).map { |flag| Note.new(code: flag["code"], headline: flag["headline"], evidence: flag["evidence"]) }
  end

  def checked? = !audit.nil?
end
