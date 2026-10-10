require "test_helper"

# A GAME THE PLAYER NARRATES, WALKED THROUGH THE SESSION WITH NOBODY AT THE
# KEYBOARD. The engine walks the mode on its own worlds (its
# tests/player_narrates.rs); this walks it where every front end does --
# `Playthrough::Session#act!`, `#play`, `#facts_card` and `#write_paragraph!`
# -- on the checked-in worlds, on a scratch copy of the database
# (`PlaysOnRust`), under `EngineSweep.without_a_model`, so a model asked for
# anywhere in a walk fails it.
#
# AFTER EVERY ACT it holds the records to the mode's promises: the engine
# picked the act and told it in its own words, the turn waits for the player's
# paragraph and the card is filled, the paragraph is kept beside the scene and
# never in it, the check leaves a note and refuses nothing, and once the
# paragraph is kept nothing waits.
#
# AND TO WHAT THE GAME HAS NOTICED (`items.noticed_at`, the engine's record):
# the panels list only noticed things, the count of what a look would show
# matches the records, the look is offered exactly while there is something
# for it, nothing noticed is ever forgotten, nothing lying in a hollow or a
# closed fixture is noticed, the card names nothing unnoticed and nothing the
# turn did not notice, and the doctor finds nothing wrong with the record.
#
# THE SAME PICKS ON EVERY RUN. The engine's die is seeded off story time and
# the submission's id, and a row's id on the scratch copy is whatever the
# tests before this one left the table's sequence at. So each walk starts the
# sequences again (`#from_the_first_id`), and a walk picks the same acts
# whatever ran before it.
class PlayerNarratesSweepTest < ActiveSupport::TestCase
  include PlaysOnRust

  setup :from_the_first_id

  test "The Salt Assizes is played to its ending with the game choosing and the player writing" do
    walked = walk("db/seeds/worlds/the-salt-assizes.yml", turns: 10)

    assert_predicate walked.game, :over?, "the arc boost should carry the walk to the story's ending"
    closing = walked.cards.last
    assert closing.ending.present?, "the turn that ended the story should carry its closing words on its card"
    assert_includes walked.actions, "move"
  end

  test "The Furnished Rooms, a world with no arc and no pursuit, is walked without a model" do
    walked = walk("lib/engine_sweep/worlds/the-furnished-rooms.yml", turns: 8)

    assert_equal 8, walked.cards.size
    assert_not_predicate walked.game, :over?
  end

  # THE KEYLESS INSTALL. The Lunar Cartographer opens in a room whose ways out
  # are all unwritten, and only a model writes a room: with none, the game has
  # nothing it may choose, and the act is refused in the engine's words rather
  # than walked into a room somebody would have to pay to write.
  test "a game with nothing it may choose is refused rather than handed to a model" do
    EngineSweep.without_a_model do
      story = WorldSeed::Loader.load_file(Rails.root.join("db/seeds/worlds/the-lunar-cartographer.yml"))
      game = Playthrough::Session.begin!(story, mode: "player_narrates").playthrough
      session = Playthrough::Session.new(game)

      outcome = act(session)

      assert_kind_of Playthrough::Refusal, outcome
      assert_equal :unplayable, outcome.kind
      assert_match(/nothing here the game can choose to do/, outcome.text)
      assert_nil session.waiting
      assert_empty game.paragraphs
    end
  end

  private

  Walked = Data.define(:game, :cards, :actions)

  # Every table's next id from where its own rows leave it, as on a database
  # nobody has written to: SQLite keeps the high-water mark of an
  # AUTOINCREMENT key apart from the rows, in `sqlite_sequence`.
  def from_the_first_id
    ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence")
  end

  def walk(world, turns:)
    EngineSweep.without_a_model do
      story = WorldSeed::Loader.load_file(Rails.root.join(world))
      game = Playthrough::Session.begin!(story, mode: "player_narrates").playthrough
      session = Playthrough::Session.new(game)
      protagonist = story.protagonist.fullname
      opening = game.current_scene
      cards = []
      actions = []

      assert_equal "player_narrates", session.glance.mode
      assert_nil session.waiting, "nothing waits before the game has acted"
      assert_nil session.facts_card(opening), "the opening is not a turn the game chose"
      noticed = holds_the_noticed_record(game, session, Set.new, "the opening")

      turns.times do |turn|
        break if game.reload.over?

        scene = act(session)
        assert_kind_of Scene, scene, "turn #{turn}: the game's act should answer a scene, not #{scene.inspect}"

        acted = scene.engine_authored? ? scene.previous_scene : scene
        actions << acted.resolved_action
        assert_equal "engine", acted.resolved_by, "turn #{turn}: the engine picked this act"
        assert_not acted.engine_fallback?, "turn #{turn}: nothing failed, so nothing fell back"
        assert acted.typed.present?, "turn #{turn}: the chosen line is written where a typed one is"
        assert_equal scene, session.waiting, "turn #{turn}: the turn waits for the player's paragraph"

        card = session.facts_card(scene)
        assert card.act.present?, "turn #{turn}: the card says what the protagonist did"
        assert_equal scene.id, card.scene
        cards << card
        before = noticed
        noticed = holds_the_noticed_record(game, session, noticed, "turn #{turn}")
        newly = Item.where(id: (noticed - before).to_a).pluck(:name)
        assert (card.noticed - newly).empty?, "turn #{turn}: the card names #{(card.noticed - newly).inspect}, " \
                                              "which this turn did not notice"
        unnoticed = game.items_lying_in(game.current_location).where(noticed_at: nil).pluck(:name)
        seen = Item.where(id: noticed.to_a).pluck(:name)
        unnoticed.reject { |name| seen.any? { |other| other.include?(name) } }.each do |name|
          assert_not_includes card.found.join(" "), name, "turn #{turn}: the card names #{name.inspect}, unnoticed"
        end

        # Clean words first, then a rewrite the check has something to say
        # about: a third person for the player, cut off mid-sentence. The
        # rewrite replaces the first, and neither is refused.
        engine_words = scene.description
        kept = session.write_paragraph!(scene, "#{card.act} #{card.people.first}".strip)
        assert kept.checked?, "turn #{turn}: a kept paragraph is checked"
        rewritten = session.write_paragraph!(scene, "#{protagonist} stands there and")
        assert_equal kept.id, rewritten.id, "turn #{turn}: a second paragraph replaces the first"
        assert_equal %w[third_person_protagonist truncated_prose], rewritten.notes.map(&:code).sort,
                     "turn #{turn}: the check should note what is wrong with the rewrite"
        assert_equal "#{protagonist} stands there and", rewritten.reload.text

        assert_equal engine_words, scene.reload.description, "turn #{turn}: the paragraph is never written into the scene"
        assert_nil session.waiting, "turn #{turn}: once the paragraph is kept nothing waits"
        assert_nil session.facts_card(opening)
      end

      assert_predicate cards, :any?
      assert_equal cards.size, game.paragraphs.count
      assert_raises(Playthrough::RustEngine::EngineError) { session.write_paragraph!(opening, "Not a chosen turn.") }

      Walked.new(game: game.reload, cards: cards, actions: actions)
    end
  end

  # THE NOTICED RECORD BETWEEN TURNS, held to the engine's promises; answers
  # the ids of every thing this game has noticed, which only ever grows.
  def holds_the_noticed_record(game, session, before, where)
    glance = session.glance
    room = game.reload.current_location
    stamped = Item.of_playthrough(game).where.not(noticed_at: nil)
    noticed = stamped.pluck(:id).to_set

    assert before.subset?(noticed), "#{where}: nothing noticed is ever forgotten"
    assert (glance.lying_here + glance.fixtures).all?(&:noticed_at), "#{where}: the panels list only noticed things"
    assert glance.carrying.all?(&:noticed_at), "#{where}: what the player carries is always noticed"
    assert_predicate stamped.where(how: "in").where.not(within_id: nil), :none?, "#{where}: nothing concealed is noticed"
    in_sight = game.items_lying_in(room).where(noticed_at: nil).reject { |item| item.within_id && item.how == "in" }
    assert_equal in_sight.size, glance.counts.unnoticed, "#{where}: the count of what a look would show"
    look = glance.verb(:examine).targets.find(&:look?)
    room_left = game.items_lying_in(room).where.not(noticed_at: nil).count < Item::Kit::MAX_VISIBLE_PER_ROOM
    assert_equal in_sight.any? && room_left, !look.nil?, "#{where}: a look is offered exactly while it would show something"
    assert_empty Story::Doctor.new(game.story).findings.select { |finding| finding.code == :noticed_record_inconsistent },
                 "#{where}: the doctor finds the record consistent"
    noticed
  end

  # LETTING THE GAME ACT, the way a front end does: accepted, then played.
  def act(session)
    submission = session.act!
    session.play(submission.command, request_token: submission.request_token)
  end
end
