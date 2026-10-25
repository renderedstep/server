require "test_helper"

# THE ENDING ONE GAME HAS EARNED AND NOT YET TAKEN. One per game, and its
# outcome is the story's main arc's.
class Playthrough::DueEndingTest < ActiveSupport::TestCase
  def setup
    @story = create(:story)
    @quest = create(:quest, story: @story)
    @rescued = create(:quest_outcome, :default, quest: @quest, name: "rescued")
    @too_late = create(:quest_outcome, quest: @quest, name: "too-late", summary: "Three days late.")
    @game = create(:playthrough, story: @story)
  end

  test "a game has at most one due ending" do
    create(:playthrough_due_ending, playthrough: @game, quest_outcome: @rescued)

    second = build(:playthrough_due_ending, playthrough: @game, quest_outcome: @too_late)

    assert_not second.valid?
    assert_equal @rescued, @game.reload.due_ending.quest_outcome
  end

  test "a side arc's outcome is never due" do
    side = create(:quest, story: @story, title: "The Locksmith's Debt", parent_quest: @quest)
    paid = create(:quest_outcome, quest: side, name: "paid")

    assert_not build(:playthrough_due_ending, playthrough: @game, quest_outcome: paid).valid?
  end

  test "an outcome from another story is refused" do
    elsewhere = create(:quest_outcome, quest: create(:quest, story: create(:story)))

    assert_not build(:playthrough_due_ending, playthrough: @game, quest_outcome: elsewhere).valid?
  end

  test "Not yet is the declined stamp" do
    due = create(:playthrough_due_ending, playthrough: @game, quest_outcome: @rescued)
    assert_not due.declined?

    due.update!(declined_at: @game.story_now)
    assert due.declined?
  end

  test "it goes with its game" do
    create(:playthrough_due_ending, playthrough: @game, quest_outcome: @rescued)

    @game.destroy!

    assert_equal 0, Playthrough::DueEnding.count
  end
end
