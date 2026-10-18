# WHAT COULD BE BROKEN OFF A FIXED PIECE, TOLD BY THE ARRIVAL: the parts
# corpus's cases.
#
# The engine tells the arrival writer what is attached to each fixed piece on a
# line of its own after the fixed pieces ("Attached to the old tree, and could
# be broken off: two branches, bark."), and only in a room whose pieces carry
# parts, so no case of the arrival corpus renders it. What this measures is
# read by hand: whether the prose names the parts, contradicts them, or has one
# come away when nobody broke it.
#
# THE SAME STAGED ARRIVAL AS THE ARRIVAL BENCH'S (`Eval::Arrival::Stage`, its
# `parts` state). Its own corpus file and its own sets, so the arrival bench
# keeps its kept set: a case added there would cost that set its digest.
module Eval::Arrival::Parts
  CORPUS = Rails.root.join("test/fixtures/files/arrival_parts_corpus.json")
  # The set bought after the line, judged against `arrival-parts-before-2026-10-18`
  # (the engine before it, on this corpus).
  BASELINE = Rails.root.join("db/eval/arrival-parts-after-2026-10-18")

  def self.cases = JSON.parse(CORPUS.read).fetch("cases")
  def self.model = Eval::Arrival.model
  def self.digest = Digest::SHA256.hexdigest(CORPUS.read)
  def self.stage = Eval::Arrival::Stage

  def self.estimate(reps: Eval::Noise::MIN_RUNS) = Eval::Arrival.estimate(reps: reps, cases: cases)
end
