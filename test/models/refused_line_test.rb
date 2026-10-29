require "test_helper"

# The refusal corpus. The engine writes the rows (its own tests hold what a row
# says); what matters here is that the table takes the row the engine writes,
# that a row outlives its game, and that nothing that leaves the machine
# carries one.
class RefusedLineTest < ActiveSupport::TestCase
  test "a kept line is new and unlabelled, with what the reader saw and answered" do
    line = create(:refused_line)

    assert_equal "new", line.reload.status
    assert_nil line.label
    assert_equal [ "Tamsin Gale", "Rowe Harker" ], line.state.fetch("people")
    assert_in_delta 0.55, line.act_confidence
    assert_equal "unsure", line.refusal.fetch("kind")
    assert_equal [ line ], RefusedLine.unlabelled.to_a
  end

  test "a line the reader never answered keeps no answers and no confidence" do
    line = create(:refused_line, :unread)

    assert_nil line.reload.answers
    assert_nil line.act_confidence
  end

  test "a status outside new, labelled and excluded is not one a row can hold" do
    assert_not_predicate build(:refused_line, status: "sent"), :valid?
    assert_not_predicate build(:refused_line, typed: ""), :valid?
  end

  test "a kept line outlives the game it was typed in" do
    playthrough = create(:playthrough)
    line = create(:refused_line, playthrough_id: playthrough.id, location_id: playthrough.current_location_id)

    playthrough.destroy!

    assert RefusedLine.exists?(line.id)
    assert_equal playthrough.id, line.reload.playthrough_id
  end

  test "the table has no foreign key, so nothing ties a row to a game" do
    assert_empty ActiveRecord::Base.connection.foreign_keys("refused_lines")
  end
end
