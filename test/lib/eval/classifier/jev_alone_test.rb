require "test_helper"
require_relative "pointer_test"

# JEV ALONE, WITH THE PROVIDER STOOD IN FOR.
#
# What is tested is that the arm sends the cascade's own System One request
# through a real `SystemOneAgent`, composes what Jev answered as the cascade
# does, answers the line the engine escalates from Jev's own readings, and
# never reaches a chat model -- and that the run's System One spend is booked
# off each answer's receipt and stops at its cap rather than crossing it. The
# HTTP transport is the fake, as `FakeAgent` is at `BaseAgent`; the lines and
# the stand-in answers are the pointer arm's (`Eval::Classifier::PointerTest`).
class Eval::Classifier::JevAloneTest < ActiveSupport::TestCase
  TOKENS = 1_500

  # Answers a System One body as Jev would, from the pointer test's table.
  class FakeTransport
    attr_reader :calls

    def initialize = @calls = 0

    def name = "typesafe_direct"
    def model = SystemOneAgent::TYPESAFE_MODEL

    def call(body)
      @calls += 1
      body = body.deep_stringify_keys
      Eval::Classifier::PointerTest::FakePointer.new.answer(body.fetch("state"), body.fetch("questions"))
                                                  .merge("usage" => { "input_tokens" => TOKENS, "output_tokens" => 40 })
    end
  end

  REFUSE_CHAT = ->(**_options) { raise "Jev alone reached BaseAgent" }

  test "jev names Jev alone, pins a transport like a cascade arm, and round-trips" do
    arm = Eval::Classifier::Arm.parse("jev+typesafe-direct")

    assert_equal [ :jev, "jev", :typesafe_direct ], [ arm.provider, arm.model, arm.system_one_transport ]
    assert_predicate arm, :jev?
    assert_predicate arm, :reads_system_one?
    assert_not_predicate arm, :chat?
    assert_not_predicate arm, :local?, "it is hosted and paid, so it runs in flight like any hosted arm"
    assert_equal "jev+typesafe-direct", arm.id
    assert_equal arm, Eval::Classifier::Arm.parse(arm.id)
    assert_equal :ambient, Eval::Classifier::Arm.parse("jev").system_one_transport
    assert_raises(Eval::Classifier::Arm::UnknownProvider) { Eval::Classifier::Arm.parse("jev+tools") }
  end

  test "its rotation is pinned empty, so a chat call reached by mistake cannot spend" do
    Eval::Classifier::Arm.parse("jev+typesafe-direct").pinned do
      assert_empty BaseAgent.default_model_options
    end
  end

  test "Jev alone reads every line through the cascade, answers an escalated line itself, and books its receipts" do
    transport = FakeTransport.new
    result = run_bench(transport, arm: "jev+typesafe-direct")

    pass = result.passes.sole
    by_id = pass.readings.index_by(&:id)
    assert_predicate result, :cascade
    assert_equal 0, pass.failures, pass.failures_by_class.inspect
    assert_in_delta 1.0, pass.accuracy
    assert_equal "typed_model", by_id["a-take"].resolved_by
    assert_equal "typed_model_escalated", by_id["a-pair"].resolved_by,
                 "the set still says which line the cascade would have sent to Mistral"
    assert_equal "typesafe_direct", by_id["a-take"].system_one_transport
    assert_not by_id["a-pair"].rotated?

    receipt = by_id["a-pair"].system_one_receipt
    assert_equal Eval::Classifier::SystemOneSpend::REPORTED, receipt["cost_source"]
    assert_in_delta TOKENS * Eval::VolitionProbe::TYPESAFE_USD_PER_INPUT_TOKEN, receipt["cost_usd"]
    assert_equal transport.calls, pass.readings.size + 1, "one request a line, and one for the warm-up"
    assert pass.rows.all? { |row| row[:system_one_receipt] }, "every row keeps what its request cost"

    out = StringIO.new
    Eval::Classifier::Report.new(result, io: out).print
    assert_match(/cost\s+\$0\.0002 over 3 System One requests, off their receipts$/, out.string)
  end

  test "a request that could cross the cap is not sent, and its line asks nothing else" do
    transport = FakeTransport.new
    result = run_bench(transport, arm: "jev+typesafe-direct", cap: 0.0001)

    pass = result.passes.sole
    assert_equal 0, transport.calls, "the stated estimate per request is above this cap, so nothing is sent"
    assert_equal pass.readings.size, pass.failures
    assert_equal [ "Eval::Classifier::SystemOneSpend::Reached" ], pass.failures_by_class.keys
  end

  test "a cascade arm whose cap is reached does not buy a Mistral call instead" do
    result = run_bench(FakeTransport.new, arm: "mistralai/mistral-medium-3.1+typesafe-direct", cap: 0.0001)

    assert_equal [ "Eval::Classifier::SystemOneSpend::Reached" ], result.passes.sole.failures_by_class.keys
  end

  private

  def run_bench(transport, arm:, cap: nil)
    corpus = Eval::Classifier::Corpus.load(written(Eval::Classifier::PointerTest::CORPUS))
    SystemOneAgent.stub(:configured?, true) do
      SystemOneAgent.stub(:build_transport, ->(_name) { transport }) do
        BaseAgent.stub(:new, REFUSE_CHAT) do
          Eval::Classifier::Bench.new(corpus: corpus, arms: [ arm ], reps: 1, io: nil, system_one_cap: cap).run
        end
      end
    end
  end

  def written(body)
    file = Tempfile.new([ "jev_alone_corpus", ".yml" ])
    file.write(body)
    file.close
    file.path
  end
end
