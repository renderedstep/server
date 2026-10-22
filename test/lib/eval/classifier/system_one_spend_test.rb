require "test_helper"

class Eval::Classifier::SystemOneSpendTest < ActiveSupport::TestCase
  Spend = Eval::Classifier::SystemOneSpend

  test "a request is priced off its own receipt, and estimated only where the receipt says nothing" do
    assert_equal [ 0.0004, Spend::REPORTED ], Spend.cost_of("openrouter_decisions", { "cost" => 0.0004 })
    usd, source = Spend.cost_of("typesafe_direct", { "input_tokens" => 2_000 })
    assert_in_delta 2_000 * Eval::VolitionProbe::TYPESAFE_USD_PER_INPUT_TOKEN, usd
    assert_equal Spend::REPORTED, source
    assert_equal [ SystemOneReceipt::COST_PER_REQUEST_USD.to_f, Spend::ESTIMATED ],
                 Spend.cost_of("openrouter_decisions", { "input_tokens" => 2_000 }),
                 "OpenRouter's tokens are not priced at TypeSafe's rate"
    assert_equal Spend::ESTIMATED, Spend.cost_of("typesafe_direct", nil).last
  end

  test "the cap stops before a request could cross it, reserving the dearest request seen" do
    spend = Spend.new(cap: 0.0025)
    answer = { "usage" => { "cost" => 0.001 } }

    _payload, receipt = spend.charge("openrouter_decisions") { answer }
    assert_equal 0.001, receipt["cost_usd"]
    spend.charge("openrouter_decisions") { answer }
    assert_raises(Spend::Reached) { spend.charge("openrouter_decisions") { flunk "sent past the cap" } }
    assert_equal({ calls: 2, estimated: 0, spent_usd: 0.002, cap_usd: 0.0025 }, spend.to_h)
  end

  test "a request that failed after it was sent is booked, because it may have been billed" do
    spend = Spend.new

    assert_raises(SystemOneAgent::Unavailable) { spend.charge("typesafe_direct") { raise SystemOneAgent::Unavailable } }
    assert_equal 1, spend.to_h[:estimated]
    assert_in_delta SystemOneReceipt::COST_PER_REQUEST_USD.to_f, spend.spent
  end
end
