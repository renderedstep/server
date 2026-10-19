require "test_helper"

# WHAT COULD BE BROKEN OFF A FIXED PIECE, BOUGHT BOTH SIDES ON THE THREE READERS
# IT IS TOLD TO: the room writer (`eval:realization CASES=iron-gate-tunnel-upward`,
# the one case whose room has a piece with a part), the arrival writer
# (`eval:arrival CORPUS=parts`) and the narrator (`eval:prompt CORPUS=parts`).
# Before is the engine before the "Attached to ..." line (renderedstep/engine
# at 32e9c11, with `Location::Generator#already_here` as it was); after is the
# pin. Four repetitions a side on Mistral medium 3.1, read by hand: no scorer
# reads a part, so every figure is a regression guard and every one is NOISE.
#
# NO DATABASE WRITE OUTSIDE A ROLLBACK, NO KEY, NO NETWORK: the after sides are
# held to the requests today's tree builds, and the before sides to those
# requests less the one line.
class Eval::PartsKeptSetsTest < ActiveSupport::TestCase
  ARM = "mistralai/mistral-medium-3.1".freeze
  LINE = /^Attached to the (?:old tree|stalagmite), and could be broken off: [^\n]*\n/

  def set(name) = Rails.root.join("db/eval", name)

  test "the arrival pair covers the parts corpus, and the after side is today's request" do
    sides = %w[before after].to_h { |side| [ side, JSON.parse(set("arrival-parts-#{side}-2026-10-18").join(Eval::Arrival::RESULTS).read) ] }
    kase = Eval::Arrival::Parts.cases.sole
    today = Eval::Arrival::Stage.open(kase) { |stage| stage.request }
    assert_includes today.fetch("user"), "Attached to the old tree, and could be broken off: two branches, bark.\n"

    sides.each do |side, data|
      assert_equal Eval::Arrival::Parts.digest, data.fetch("corpus_digest"), side
      assert_equal Eval::Arrival::Parts.model, data.fetch("model"), side
      assert_equal Eval::Noise::MIN_RUNS, data.fetch("reps"), side
      assert_equal [ 1, 2, 3, 4 ], data.fetch("rows").map { |row| row.fetch("rep") }, side
      data.fetch("rows").each do |row|
        assert_nil row["error"]
        expected = side == "after" ? today : today.merge("user" => today.fetch("user").sub(LINE, ""))
        assert_equal [ expected ], row.fetch("requests"), side
        assert_operator row.fetch("calls").sole.fetch("provider_cost_usd"), :>, 0
      end
    end
    before, after = sides.values.map { |data| Eval::Arrival::Result.new(data) }
    assert before.compare(after).all? { |metric| metric.fetch(:outcome) == :noise }
  end

  test "the narrator pair scored the parts corpus, and the after side is today's request" do
    corpus = Eval::Prompt.corpus("parts")
    here = Eval::Prompt::RequestVersion.offline(corpus)
    prompt = Eval::Prompt::RequestVersion.requests(corpus).fetch("break").fetch(:user)
    assert_includes prompt, "Attached to the old tree, and could be broken off: two branches, bark.\n"

    %w[before after].each do |side|
      kept = Eval::Prompt::Result.load(set("prompt-parts-#{side}-2026-10-18"))
      assert_equal Eval::Prompt.digest(corpus), kept.corpus_digest, side
      assert_equal [ ARM ], kept.arms, side
      assert_equal kept.arms, kept.answered_by, side
      assert_equal Eval::Noise::MIN_RUNS, kept.reps, side
      assert_equal Eval::Noise::MIN_RUNS, kept.rows.size, side
      # The narrator's moment sets each line off with a blank one.
      kept.rows.each { |row| assert_equal(side == "after" ? prompt : prompt.sub(/#{LINE}\n/, ""), row.fetch("prompt"), side) }
    end
    assert_equal here.fetch(:prompt_digest), Eval::Prompt::Result.load(set("prompt-parts-after-2026-10-18")).prompt_digest
    assert_empty corpus.problems
  end

  test "the room writer pair built the one case with a part, and only the after side was told it" do
    corpus = Eval::Realization.corpus.subset { |kase| kase.id == "iron-gate-tunnel-upward" }
    %w[before after].each do |side|
      kept = Eval::Realization::Result.load(set("realization-parts-#{side}-2026-10-18"))
      assert_equal Eval::Realization.digest(corpus), kept.corpus_digest, side
      assert_equal [ ARM ], kept.arms, side
      assert_equal Eval::Noise::MIN_RUNS, kept.reps, side
      told = kept.rows.map { |row| row.fetch("prompts").fetch("detail").include?("Attached to the stalagmite, and could be broken off: stalagmite tip.\n") }
      assert_equal [ side == "after" ] * Eval::Noise::MIN_RUNS, told, side
    end
  end

  test "the manifest names every set, so deleting one is a failing test" do
    %w[realization prompt arrival].product(%w[before after]).each do |bench, side|
      file = { "realization" => Eval::Realization::RESULTS, "prompt" => Eval::Prompt::RESULTS,
               "arrival" => Eval::Arrival::RESULTS }.fetch(bench)
      assert_includes Eval::MEASUREMENT_FILES, "db/eval/#{bench}-parts-#{side}-2026-10-18/#{file}"
    end
  end
end
