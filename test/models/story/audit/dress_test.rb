require "test_helper"

# `dress_invented`: the prose puts a thing on the player or takes it off, on a
# turn that did not.
class Story::Audit::DressTest < ActiveSupport::TestCase
  # A `/wear oilskin coat` told by a narrator that did what it was told.
  WORN = "You shrug on the oilskin coat, and the cold off the estuary stops at its collar.".freeze

  # The same coat put on by the narrator of an `examine`.
  INVENTED = "The hand-bell is green at the lip. You pull on the oilskin coat against the draught.".freeze

  # And taken off by the narrator of a talk.
  TAKEN_OFF = "Abel nods at the bench. You take off your coat and hang it on a peg.".freeze

  setup do
    @story = create(:story)
    @room = create(:location, story: @story, name: "The Cloakroom")
    @player = create(:character, :protagonist, story: @story)
    template = create(:item, character: nil, location: @room, name: "oilskin coat", wear: "outer")
    @game = create(:playthrough, story: @story, character: @player, current_location: @room)
    @coat = @game.items.find_by!(template: template)
    @coat.update!(location: nil, character: nil, x: nil, y: nil)
  end

  def scene_with(text, action:, acted_on: nil)
    create(:scene, story: @story, location: @room, description: text, resolved_action: action,
                   acted_on: acted_on, story_timestamp: @story.start_time)
  end

  def found = Story::Audit.new(@story).flags.select { |flag| flag.code == :dress_invented }

  test "a wear of the coat that the prose tells is clean" do
    scene_with(WORN, action: "wear", acted_on: @coat)

    assert_empty found
  end

  test "the coat put on by the prose of a turn that did not put it on" do
    scene = scene_with(INVENTED, action: "examine")

    assert_equal [ scene ], found.map(&:scene)
    assert_predicate found.first, :contradiction?
    assert_equal "oilskin coat", found.first.evidence[:item]
    assert_match(/puts on the oilskin coat/, found.first.headline)
  end

  test "the coat taken off on a talk, and on a wear of it" do
    talk = scene_with(TAKEN_OFF, action: "talk")
    wear = scene_with(TAKEN_OFF, action: "wear", acted_on: @coat)

    assert_equal [ talk, wear ], found.map(&:scene)
    assert_match(/takes off the oilskin coat/, found.first.headline)
  end

  test "a thing nobody wears is not read" do
    @coat.update!(wear: nil)
    scene_with(INVENTED, action: "examine")

    assert_empty found
  end

  test "the grammars, and what each must not read" do
    names = Story::Audit::Prose.item_names("oilskin coat")
    claims = ->(text) { Story::Audit::Prose.dress_claims(text, names).map { |c| [ c.name, c.direction ] } }

    assert_equal [ [ "oilskin coat", :on ] ], claims.("You pull on the oilskin coat.")
    assert_equal [ [ "coat", :on ] ], claims.("You shrug the coat back on.")
    assert_equal [ [ "coat", :on ] ], claims.("You don the coat.")
    assert_equal [ [ "coat", :off ] ], claims.("You take off your coat.")
    assert_equal [ [ "coat", :off ] ], claims.("You slip the coat off.")
    assert_equal [ [ "coat", :off ] ], claims.("You remove the coat.")

    assert_empty claims.("You put the coat on the counter.")
    assert_empty claims.("You take the coat off the peg.")
    assert_empty claims.("You remove the coat from the hook.")
    assert_empty claims.("You do not take off the coat.")
    assert_empty claims.("You pull the coat tighter.")
    assert_empty claims.("\"Take off your coat,\" Abel says.")
    assert_empty claims.("You shrug it on.")
  end
end
