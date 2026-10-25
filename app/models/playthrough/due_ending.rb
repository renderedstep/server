# THE ENDING ONE GAME HAS EARNED AND NOT YET TAKEN.
#
# `Playthrough::Ending` one step earlier. The line that meets the main arc's
# last beat picks the outcome there and then, by the rules that used to end the
# game on the spot, and writes it here -- no ending row, no closing scene, no
# `ended_at`. The outcome is fixed from that moment: nothing played afterwards
# (time passing, a death, a beat out of order) changes which ending `/end`
# writes. `declined_at` is "Not yet", stamped by the button or by any other
# line, so the offer is made once.
#
# WRITTEN BY THE ENGINE AND BY NOTHING ELSE (renderedstep/engine `turn.rs`,
# `Engine::put_off_ending`). What a front end shows for it is read off the
# glance -- `ending_due` and `ending_offer` -- never off this row.
#
# ONE PER GAME, and the unique index says so. Its outcome is the story's main
# arc's, and the ending row `/end` writes names the same outcome; the doctor
# reports a game where either is not so (`Story::Doctor`).
class Playthrough::DueEnding < ApplicationRecord
  self.table_name = "playthrough_due_endings"

  belongs_to :playthrough
  belongs_to :quest_outcome, class_name: "Quest::Outcome"

  validates :due_at, presence: true
  validates :playthrough_id, uniqueness: true
  validate :outcome_belongs_to_the_main_arc

  def declined? = declined_at.present?

  private

  def outcome_belongs_to_the_main_arc
    return if quest_outcome.nil? || playthrough.nil?
    return if quest_outcome.quest == Quest.main_arc(playthrough.story)

    errors.add(:quest_outcome, "must belong to the main arc of the playthrough's story")
  end
end
