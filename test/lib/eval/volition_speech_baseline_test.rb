require "test_helper"

# THE KEPT VOLITION BASELINE WITH THE SPEECH QUESTION, RE-SCORED FOR FREE.
#
# `rake eval:volition_baseline_summary SET=volition-speech-baseline-20261004`
# prints what this reads. The figures pinned here are the ones the set's
# README reports, so a change to the summary that would move a reported
# number fails here first.
class Eval::VolitionSpeechBaselineTest < ActiveSupport::TestCase
  SET = "volition-speech-baseline-20261004".freeze
  BEFORE = "volition-baseline-20260926".freeze

  setup { @summary = Eval::VolitionProbe::Baseline.summary(SET) }

  test "every call answered and none failed" do
    assert_equal 48, @summary["calls"]
    assert_equal 48, @summary["succeeded"]
    assert_empty @summary["failed"]
  end

  test "the set was measured on the speech rooms the fixture pins today" do
    kept = JSON.parse(Eval::VolitionProbe::ROOT.join(SET, "receipts.json").read)

    assert_equal "typesafe_direct", kept["transport"]
    assert_equal Digest::SHA256.file(Eval::VolitionProbe::ROOT.join(SET, "requests.json")).hexdigest, kept["requests_sha256"]
    assert_equal Eval::VolitionProbe::SPEECH_ROOMS.read, Eval::VolitionProbe::ROOT.join(SET, "requests.json").read
  end

  test "the headline figures recompute" do
    assert_equal 56, @summary["answers"]
    assert_equal 48, @summary["pressure_crossed"]
    assert_equal({ "give" => 2, "move" => 8, "take" => 8, "wait" => 38 }, @summary["shapes_chosen"])
    assert_equal 48, @summary["speech_answers"]
    assert_equal({ "greet" => 12, "silent" => 36 }, @summary["speech_chosen"])
    assert_in_delta 0.001854216, @summary["receipt_total"], 1e-12
  end

  test "beside the speech question, every person's acts and serves are what they were without it" do
    before = Eval::VolitionProbe::Baseline.summary(BEFORE)["people"]
    before.zip(@summary["people"]).each do |was, now|
      assert_equal [ was["room"], was["name"] ], [ now["room"], now["name"] ]
      assert_equal was["reps"].map { |rep| rep["act"] }.tally, now["reps"].map { |rep| rep["act"] }.tally, now["name"]
      assert_equal was["reps"].map { |rep| rep["serves"] }, now["reps"].map { |rep| rep["serves"] }, now["name"]
      assert_in_delta was["pressure_mean"], now["pressure_mean"], 0.01 + 1e-9, now["name"]
    end
  end

  test "every speech answer is one the room offered" do
    @summary["people"].flat_map { |p| p["reps"] }.select { |rep| rep["speech"] }.each do |rep|
      assert rep["speech_option"], rep.inspect
    end
  end
end
