require "test_helper"

# `destruction_invented`: the prose tears, burns or breaks a thing the records
# still have whole.
#
# THE TWO PASSAGES BELOW ARE A REAL GAME'S, copied byte for byte from the
# deployment's database: "Tear up the closet writ" was read as a take of the
# blank closure writ, the arc's last goal, so the row was picked up whole and
# the story concluded. TURN is that turn's narration and ENDING the ending
# written after it. The writ was carried and intact under both.
class Story::Audit::DestructionTest < ActiveSupport::TestCase
  TURN = "You lift the blank closure writ from the tube basket, the heavy grey stock crisp between your fingers. " \
         "The paper resists at first, then gives with a sharp, final tear as you rend it cleanly in two. The " \
         "pieces flutter to the desk, the words *\"WRIT OF CLOSURE — Ward 12. The file of " \
         "______________________ is closed, no query to be raised. By order of the Inspectorate. " \
         "Countersigned.\"* now split across the fragments. The gas mantle hisses overhead, indifferent. The " \
         "rain keeps its rhythm against the window. The torn halves lie where they fell, and the office does " \
         "not react.".freeze

  ENDING = "You tear the writ in half, the heavy paper parting with a sound like a held breath released, and the " \
           "office does not stir—no footfall in the hall, no voice from the closet, no hand reaching for the " \
           "pieces. The gap in your daybook stays open, the stamp beside it dry, and the torn halves of the writ " \
           "lie between you and the empty desk as if they had always been there.".freeze

  # The same ending told from the records: the writ taken, and whole.
  CLEAN = "You fold the writ once and slip it inside your coat, beside the index. The office does not stir, and " \
          "the rain keeps its rhythm against the window.".freeze

  setup do
    @story = create(:story)
    @room = create(:location, story: @story, name: "Ward Office 12")
    @player = create(:character, :protagonist, story: @story)
    template = create(:item, character: nil, location: @room, name: "blank closure writ")
    @game = create(:playthrough, story: @story, character: @player, current_location: @room)
    @writ = @game.items.find_by!(template: template)
  end

  def carry_writ! = @writ.update!(location: nil, character: nil, x: nil, y: nil)

  def scene_with(text, action: "ending")
    create(:scene, story: @story, location: @room, description: text, resolved_action: action,
                   story_timestamp: @story.start_time)
  end

  def found = Story::Audit.new(@story).flags.select { |flag| flag.code == :destruction_invented }

  test "the real ending tears a writ the records have carried and whole" do
    carry_writ!
    scene = scene_with(ENDING)

    assert_equal [ scene ], found.map(&:scene)
    assert_predicate found.first, :contradiction?
    assert_equal "blank closure writ", found.first.evidence[:item]
    assert_equal "intact, carried by the player", found.first.evidence["records say"]
    assert_match(/\AYou tear the writ in half/, found.first.evidence[:claim])
  end

  test "the same ending told from the records is clean" do
    carry_writ!
    scene_with(CLEAN)

    assert_empty found
  end

  test "a thing lying in the room is read too, and one lying elsewhere is not" do
    scene = scene_with(ENDING)
    assert_equal [ scene ], found.map(&:scene)

    @writ.update!(location: create(:location, story: @story))
    assert_empty found
  end

  test "a name with a spent copy in any game is not read" do
    carry_writ!
    other = create(:playthrough, story: @story, character: @player, current_location: @room)
    other.items.find_by!(name: "blank closure writ").update!(disposition: "burned", location: nil, character: nil,
                                                              x: nil, y: nil)
    scene_with(ENDING)

    assert_empty found
  end

  test "a row changed after the scene was written is unjudged" do
    scene = scene_with(ENDING)
    carry_writ!
    @writ.update_columns(updated_at: scene.created_at + 1.minute)

    audit = Story::Audit.new(@story)
    assert_empty audit.flags.select { |flag| flag.code == :destruction_invented }
    assert_equal [ scene ], audit.unjudged.select { |skipped| skipped.code == :destruction_invented }.map(&:scene)
  end

  test "the turn's own narration is the stated miss: it tears the writ under a pronoun" do
    names = Story::Audit::Prose.item_names("blank closure writ")

    assert_empty Story::Audit::Prose.destruction_claims(TURN, names)
  end

  test "the three grammars, and what each must not read" do
    names = Story::Audit::Prose.item_names("Perrin's private index")
    claims = ->(text) { Story::Audit::Prose.destruction_claims(text, names).map(&:name) }

    assert_equal [ "index" ], claims.("You rip up the index and let the pieces fall.")
    assert_equal [ "index" ], claims.("The charred remains of the index curl in the grate.")
    assert_equal [ "index" ], claims.("The index, torn down its spine, lies on the desk.")

    assert_empty claims.("You do not tear the index; you set it down.")
    assert_empty claims.("A broken chair stands beside the index.")
    assert_empty claims.("You are a clerk who destroyed a stamped index without a form.")
    assert_empty claims.("The lamp burns low over the index.")
    assert_empty claims.("\"Burn the index,\" Rowe says.")
  end
end
