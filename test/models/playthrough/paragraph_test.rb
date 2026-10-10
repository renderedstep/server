require "test_helper"

# The player's paragraph, in a game they narrate: prose kept beside the turn,
# one per author per scene, and a check's finding read back as notes. Who
# writes the row and when it is checked are the engine's and the session's,
# and `Playthrough::PlayerNarratesTest` holds those.
class Playthrough::ParagraphTest < ActiveSupport::TestCase
  test "a paragraph is valid with a game, a turn and some words" do
    assert_predicate build(:playthrough_paragraph), :valid?
  end

  test "a paragraph with no words is not one" do
    paragraph = build(:playthrough_paragraph, text: "  ")

    assert_not_predicate paragraph, :valid?
    assert_includes paragraph.errors[:text], "can't be blank"
  end

  test "only the player writes one today" do
    paragraph = build(:playthrough_paragraph, author: "narrator")

    assert_not_predicate paragraph, :valid?
    assert_includes paragraph.errors[:author], "is not included in the list"
  end

  test "a turn has one paragraph per author" do
    kept = create(:playthrough_paragraph)
    second = build(:playthrough_paragraph, playthrough: kept.playthrough, scene: kept.scene)

    assert_not_predicate second, :valid?
    assert_raises(ActiveRecord::RecordNotUnique) { second.save!(validate: false) }
  end

  test "an unchecked paragraph has no notes, and a checked one says what was found" do
    assert_nil build(:playthrough_paragraph).notes
    assert_not_predicate build(:playthrough_paragraph), :checked?
    assert_equal [], build(:playthrough_paragraph, :checked).notes

    note = build(:playthrough_paragraph, :flagged).notes.sole
    assert_equal "truncated_prose", note.code
    assert_equal "the narration the player read stops mid-sentence", note.headline
    assert_equal "…and then the", note.evidence
  end

  test "whose it is is the game's player" do
    player = create(:player)
    paragraph = create(:playthrough_paragraph, playthrough: create(:playthrough, player: player, mode: "player_narrates"))

    assert_equal player, paragraph.player
  end

  test "it goes with its game and with its turn" do
    paragraph = create(:playthrough_paragraph)
    assert_difference -> { Playthrough::Paragraph.count }, -1 do
      paragraph.scene.destroy!
    end

    other = create(:playthrough_paragraph)
    assert_difference -> { Playthrough::Paragraph.count }, -1 do
      other.playthrough.destroy!
    end
  end

  test "a paragraph is kept for its game alone unless something says otherwise" do
    assert_equal "none", create(:playthrough_paragraph).consent
    assert_predicate build(:playthrough_paragraph, consent: "owner"), :valid?

    paragraph = build(:playthrough_paragraph, consent: "everyone")
    assert_not_predicate paragraph, :valid?
    assert_includes paragraph.errors[:consent], "is not included in the list"
  end

  test "the owner's consent goes only to a game nobody was invited to" do
    assert_equal "owner", Playthrough::Paragraph.consent_for(build(:playthrough))
    assert_equal "none", Playthrough::Paragraph.consent_for(build(:playthrough, player: build(:player)))
  end

  # ELIGIBLE ASKS BOTH THE WORD AND THE GAME, so a row that says `owner` in an
  # invited player's game -- however it came to say so -- is never in a set.
  test "only the owner's own paragraphs, beside a request, are eligible for a set" do
    owners = create(:playthrough_paragraph, :captured)
    kept_for_the_game = create(:playthrough_paragraph, :captured, consent: "none")
    no_request = create(:playthrough_paragraph, :captured, requests: nil)
    invited = create(:playthrough_paragraph, :captured,
                     playthrough: create(:playthrough, player: create(:player), mode: "player_narrates"))

    assert_equal [ owners ], Playthrough::Paragraph.eligible.to_a
    assert_predicate owners, :eligible?
    [ kept_for_the_game, no_request, invited ].each { |paragraph| assert_not_predicate paragraph, :eligible? }
  end

  test "it reads back the requests it stands in for, the act's first" do
    paragraph = build(:playthrough_paragraph, :captured)

    assert_equal "narration", paragraph.act_request["purpose"]
    assert_equal paragraph.prompt_digest, paragraph.act_request["prompt_digest"]
    assert_equal [], build(:playthrough_paragraph).would_ask
    assert_nil build(:playthrough_paragraph).act_request
  end

  test "a game is told one of two ways, narrated unless it says otherwise" do
    assert_equal "narrated", create(:playthrough).mode
    assert_not_predicate create(:playthrough), :player_narrates?
    assert_predicate build(:playthrough, mode: "player_narrates"), :player_narrates?

    assert_not_predicate build(:playthrough, mode: "sung"), :valid?
  end
end
