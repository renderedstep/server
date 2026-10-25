require "test_helper"

# END THE STORY HERE? The line that meets the last beat fixes the ending and
# asks; "End the story" plays `/end`, "Not yet" withdraws the question and
# leaves a standing button. The words are the engine's (`Glance#ending_offer`).
class EndingOfferTest < ActionDispatch::IntegrationTest
  include PlaysOnRust

  WORLD = Rails.root.join("lib/engine_sweep/worlds/the-iron-gate-descends.yml")
  TO_THE_LAST_BEAT = [ "take the signet ring", "go to the obsidian maw", "go to Blackfang Tunnel",
                       "go to Blackfang Warren room 1", "go to Blackfang Warren room 2", "go to the dry cell" ].freeze

  setup do
    story = WorldSeed::Loader.new(YAML.safe_load_file(WORLD)).load!
    @game = Playthrough::Session.begin!(story).playthrough
    TO_THE_LAST_BEAT.each { |line| Playthrough::RustEngine.play(@game, line) }
    @session = Playthrough::Session.new(@game.reload)
  end

  test "meeting the last beat asks, in the engine's words, and ends nothing" do
    offer = @session.glance.ending_offer

    assert_not_predicate @game, :over?
    assert_predicate @session.glance, :ending_due?
    assert_equal "/end", offer.end_line
    assert_not_nil @game.due_ending

    get playthrough_path(@game)

    assert_select ".ending-offer .sheet-lead", text: offer.heading
    assert_select ".ending-offer li", count: offer.goals.size
    assert_select ".ending-offer input[type=hidden][name=command][value='/end']"
    assert_select ".ending-offer input[type=submit][value=?]", offer.end
    assert_select ".ending-offer input[type=submit][value=?]", offer.not_yet
  end

  test "Not yet withdraws the question and leaves a standing End the story" do
    post put_off_ending_playthrough_turns_path(@game)

    assert_redirected_to playthrough_path(@game, anchor: "bottom")
    assert_nil @session.glance.ending_offer
    assert_predicate @session.glance, :ending_due?
    assert_not_nil @game.due_ending.reload.declined_at

    get playthrough_path(@game)

    assert_select ".ending-offer", count: 0
    assert_select ".ending-due input[type=submit][value='End the story']"
  end

  test "/end writes the ending that fell due" do
    due = @game.due_ending

    Playthrough::RustEngine.play(@game, "/end")

    assert_predicate @game.reload, :over?
    assert_equal due.quest_outcome, @game.endings.sole.quest_outcome
    assert_not @session.glance.ending_due?
    assert_nil @session.glance.ending_offer
  end
end
