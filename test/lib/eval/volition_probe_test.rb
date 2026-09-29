require "test_helper"

# WHERE THE VOLITION BENCH SENDS ITS CALLS, AND WHAT IT SAYS EACH COST.
#
# Offline: nothing here posts. The bench takes TypeSafe direct when its key is
# present, as `SystemOneAgent` does, and prices a TypeSafe answer from the
# tokens it reports, because TypeSafe reports no price; the ceiling that stops
# a run reads that price, so a receipt with none would stop it.
class Eval::VolitionProbeTest < ActiveSupport::TestCase
  def with_keys(typesafe:, openrouter:)
    saved = ENV.to_h.slice("TYPESAFE_API_KEY", "OPENROUTER_API_KEY")
    ENV["TYPESAFE_API_KEY"] = typesafe
    ENV["OPENROUTER_API_KEY"] = openrouter
    yield
  ensure
    ENV.delete("TYPESAFE_API_KEY")
    ENV.delete("OPENROUTER_API_KEY")
    ENV.update(saved)
  end

  test "TypeSafe direct answers when its key is present, as the game's does" do
    with_keys(typesafe: "ts-key", openrouter: "or-key") do
      via = Eval::VolitionProbe.transport

      assert_predicate via, :typesafe?
      assert_equal SystemOneAgent::TYPESAFE_ENDPOINT, via.endpoint
      assert_equal SystemOneAgent::TYPESAFE_MODEL, via.model
    end
    with_keys(typesafe: nil, openrouter: "or-key") do
      via = Eval::VolitionProbe.transport

      assert_not_predicate via, :typesafe?
      assert_equal SystemOneAgent::OPENROUTER_MODEL, via.model
    end
  end

  test "a TypeSafe answer costs its input tokens at the published rate, and OpenRouter's says its own" do
    typesafe = Eval::VolitionProbe::Transport.new(name: "typesafe_direct", endpoint: nil, model: nil, key: nil)
    openrouter = Eval::VolitionProbe::Transport.new(name: "openrouter_decisions", endpoint: nil, model: nil, key: nil)

    assert_in_delta 3.297e-05, Eval::VolitionProbe.cost_of(typesafe, { "input_tokens" => 785, "output_tokens" => 155 }), 1e-15
    assert_nil Eval::VolitionProbe.cost_of(typesafe, { "output_tokens" => 155 })
    assert_in_delta 3.297e-05, Eval::VolitionProbe.cost_of(openrouter, { "cost" => 3.297e-05 }), 1e-15
  end

  test "a speech set reads what each person said off the option it was offered under" do
    assert_equal "silent", Eval::VolitionProbe::Baseline.speech_shape_of("Say nothing.")
    assert_equal "greet", Eval::VolitionProbe::Baseline.speech_shape_of("Greet Odile Vance.")
    assert_equal "dismiss", Eval::VolitionProbe::Baseline.speech_shape_of("Tell Odile Vance to leave Ward Office 12.")
    assert_equal "demand", Eval::VolitionProbe::Baseline.speech_shape_of("Demand the deed from Coraith Vell.")
  end
end
