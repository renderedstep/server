require "test_helper"

# `division_untold`: the records say a tear or a smash divided a thing and the
# fact the writer was handed does not say so. Two records against each other
# and no prose, as `break_untold` is.
#
# THE RECEIPTS BELOW ARE THE RUST ENGINE'S OWN WORDS for a tear that came off
# and one that held (its `facts::divided`), copied here because the writer is
# in that engine and not in this repository.
class Story::Audit::DivisionTest < ActiveSupport::TestCase
  TORN = "ON THIS TURN, and not before it, Ada Hollin tore the letter apart. The letter is gone: it is in no " \
         "place now, and nobody can carry or use it whole again. What is left of it is the scraps of the letter, " \
         "lying where it was. The tearing is what has just happened and it is what to narrate. Do not write the " \
         "letter whole again, or anything else being broken, picked up or carried.".freeze

  HELD = "ON THIS TURN, and not before it, Ada Hollin tried to tear the letter apart. The letter held together: " \
         "it is whole, and nothing changed. Do not write it tearing, breaking or coming apart.".freeze

  setup do
    @story = create(:story)
    @room = create(:location, story: @story)
    @player = create(:character, :protagonist, story: @story)
    template = create(:item, character: nil, location: @room, name: "letter")
    @game = create(:playthrough, story: @story, character: @player, current_location: @room)
    @letter = @game.items.find_by!(template: template)
  end

  def scene_for(action, engine_fact, at: @story.start_time)
    create(:scene, story: @story, location: @room, description: "The letter comes apart in your hands.",
                   engine_fact: engine_fact, resolved_action: action, acted_on: @letter, story_timestamp: at)
  end

  def divide_letter! = @letter.update!(disposition: "divided", location: nil, character: nil, x: nil, y: nil)

  def audit = Story::Audit.new(@story)

  def codes(audit) = audit.flags.map(&:code)

  test "a tear that divided a thing and told the writer so is not flagged" do
    divide_letter!
    scene_for("tear", TORN)

    assert_not_includes codes(audit), :division_untold
    assert_equal 1, audit.judgeable_for(:division_untold)
  end

  test "a tear that divided a thing and told the writer it held is flagged" do
    divide_letter!
    scene = scene_for("tear", HELD)

    found = audit.flags.select { |flag| flag.code == :division_untold }
    assert_equal [ scene ], found.map(&:scene)
    assert_predicate found.first, :contradiction?
    assert_equal "letter", found.first.evidence[:item]
  end

  test "only the last tear or smash of a divided thing is the one that divided it" do
    first = scene_for("tear", HELD)
    last = scene_for("smash", TORN, at: @story.start_time + 60)
    divide_letter!

    assert_not_includes codes(audit), :division_untold
    assert_not audit.send(:divided_on?, first)
    assert audit.send(:divided_on?, last)
  end

  test "a thing that held together has nothing to leave untold" do
    scene_for("tear", HELD)

    assert_equal 0, audit.judgeable_for(:division_untold)
  end

  test "a divided thing's turn with no receipt is unjudged, never flagged" do
    divide_letter!
    scene = scene_for("tear", nil)

    assert_not_includes codes(audit), :division_untold
    assert_equal [ scene ], audit.unjudged.select { |skipped| skipped.code == :division_untold }.map(&:scene)
  end
end
