require "test_helper"

class SystemOneReceiptTest < ActiveSupport::TestCase
  test "a receipt is filed under whoever the current turn belongs to, at the stated estimate" do
    player = create(:player)
    game = create(:playthrough, player: player)
    receipt = Current.set(player: player, playthrough: game) { SystemOneReceipt.record!(purpose: "classifier", transport: :typesafe_direct) }

    assert_equal player, receipt.player
    assert_equal game, receipt.playthrough
    assert_equal "typesafe_direct", receipt.transport
    assert_equal SystemOneReceipt::COST_PER_REQUEST_USD, receipt.cost_usd
    assert_equal SystemOneReceipt::ESTIMATED, receipt.cost_source
  end

  test "a reported cost below the estimate is booked and marked reported" do
    receipt = create(:system_one_receipt, transport: "openrouter_decisions")
    receipt.reported!({ "input_tokens" => 874, "output_tokens" => 202, "cost" => 0.000037 })

    receipt.reload
    assert_equal BigDecimal("0.000037"), receipt.cost_usd
    assert receipt.reported?
  end

  test "a reported cost above the estimate is booked too" do
    receipt = create(:system_one_receipt, transport: "openrouter_decisions")
    receipt.reported!({ "cost" => 0.01 })

    assert_equal BigDecimal("0.01"), receipt.reload.cost_usd
    assert receipt.reported?
  end

  test "an answer with no usable cost keeps the estimate, marked estimated" do
    receipt = create(:system_one_receipt)
    [ nil, {}, { "input_tokens" => 874, "output_tokens" => 202 }, { "cost" => -1 }, { "cost" => Float::NAN }, { "cost" => "free" } ].each do |usage|
      receipt.reported!(usage)
    end

    receipt.reload
    assert_equal SystemOneReceipt::COST_PER_REQUEST_USD, receipt.cost_usd
    assert_equal SystemOneReceipt::ESTIMATED, receipt.cost_source
  end

  test "a row from before latency was kept stays NULL, and a negative wait is refused" do
    assert_nil create(:system_one_receipt).latency_ms
    assert_not build(:system_one_receipt, latency_ms: -1).valid?
  end

  test "the three volition purposes and the older combined one read as one family" do
    purposes = [ *SystemOneReceipt::VOLITION_PURPOSES, SystemOneReceipt::VOLITION_COMBINED, SystemOneReceipt::CLASSIFIER ]
    purposes.each { |purpose| create(:system_one_receipt, purpose: purpose) }

    assert_equal %w[volition volition_acts volition_reactions volition_speech], SystemOneReceipt.volition.pluck(:purpose).sort
    assert_equal 1, SystemOneReceipt.where(purpose: SystemOneReceipt::VOLITION_SPEECH).count, "each split purpose is filed apart"
  end

  test "a cost source outside the two is refused" do
    assert_not build(:system_one_receipt, cost_source: "guessed").valid?
  end
end
