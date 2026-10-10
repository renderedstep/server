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
# belong to nobody, which is to say to the owner, who plays them.
#
# BESIDE IT, THE REQUEST IT STANDS IN FOR. The engine builds the request a
# narrator would have been sent for the turn, sends nothing, and copies it onto
# this row when the paragraph is kept: `requests` holds one entry per pass
# (`{purpose, prompt_digest, request}`, `narration` or `arrival` and then
# `ending` on the turn that closed the story) and `prompt_digest` the act's
# digest, computed as `Playthrough::PromptVersion.for_chat` computes it. So a
# paragraph is a reference written against the very request a model would have
# answered; `Playthrough::Paragraph::Export` is what reads that.
#
# WHAT IT MAY BE USED FOR is `consent`, a closed set the engine also knows
# (`narrates::Consent`): `none` is kept for its game alone, `owner` is the
# owner's own paragraph for a private reference set. Nothing but
# `Playthrough::Session#write_paragraph!` picks it, and it picks `owner` only
# for a game with no player. ELIGIBLE asks both -- the word and a game with no
# player -- so an invited player's paragraph is never in a set, whatever word a
# row carries, until a per-player opt-in exists.
class Playthrough::Paragraph < ApplicationRecord
  self.table_name = "playthrough_paragraphs"

  # WHO WROTE IT. Only the player today; the column is there so a narrator's
  # paragraph for the same scene can sit beside it later.
  AUTHORS = %w[player].freeze

  # WHAT THE PLAYER LET IT BE USED FOR, the engine's words. `none` is the
  # column's default and every paragraph's until something says otherwise.
  NONE = "none".freeze
  OWNER = "owner".freeze
  CONSENTS = [ NONE, OWNER ].freeze

  belongs_to :playthrough, inverse_of: :paragraphs
  belongs_to :scene, inverse_of: :paragraphs
  has_one :player, through: :playthrough

  validates :author, inclusion: { in: AUTHORS }, uniqueness: { scope: :scene_id }
  validates :text, presence: true
  validates :consent, inclusion: { in: CONSENTS }

  # THE PARAGRAPHS A PRIVATE REFERENCE SET MAY HOLD: the owner's, in a game no
  # invited player plays, with the request they stand in for on the row.
  scope :eligible, lambda {
    where(consent: OWNER, author: "player").where.not(requests: nil)
                                            .joins(:playthrough).where(playthroughs: { player_id: nil })
  }

  # The consent a paragraph written in `playthrough` is kept with: the owner's
  # for a game nobody was invited to, nothing for any other.
  def self.consent_for(playthrough) = playthrough.player.nil? ? OWNER : NONE

  def eligible? = consent == OWNER && author == "player" && requests.present? && playthrough.player.nil?

  # The requests a narrator would have been sent for the turn, in the order a
  # narrated game sends them; empty for a turn played before they were kept.
  def would_ask = Array(requests)

  # The request for the turn's own act (`narration` or `arrival`), the one
  # `prompt_digest` is the digest of.
  def act_request = would_ask.first

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
