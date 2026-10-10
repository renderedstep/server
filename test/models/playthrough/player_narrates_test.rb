require "test_helper"

# A GAME THE PLAYER NARRATES, through `Playthrough::Session`: the mode chosen
# at Play, letting the game act, the facts card and the paragraph -- what each
# answers in the other mode and for a turn the game did not choose. Played on
# the Rust engine, on a scratch copy (`PlaysOnRust`). The walk over whole
# worlds is `PlayerNarratesSweepTest`.
class Playthrough::PlayerNarratesTest < ActiveSupport::TestCase
  include PlaysOnRust

  setup do
    @story = WorldSeed::Loader.load_file(Rails.root.join("db/seeds/worlds/the-salt-assizes.yml"))
  end

  test "a game is narrated unless the player chose otherwise at Play, and keeps what they chose" do
    assert_equal "narrated", Playthrough::Session.begin!(@story).playthrough.reload.mode
    assert_equal "player_narrates", begin_narrating.reload.mode
  end

  test "letting the game act is a submission like a typed line's, carrying the engine's line" do
    game = begin_narrating

    submission = Playthrough::Session.new(game).act!("act-1")

    assert_equal Playthrough::RustEngine::ACT_LINE, submission.command
    assert_equal "act-1", submission.request_token
    assert_equal "pending", submission.status
  end

  test "a narrated game cannot be told to act, and nothing is written" do
    game = Playthrough::Session.begin!(@story).playthrough

    assert_no_difference -> { Playthrough::Command.count } do
      assert_nil Playthrough::Session.new(game).act!
    end
    assert_nil Playthrough::Session.new(game).waiting
    assert_nil Playthrough::Session.new(game).facts_card(game.current_scene)
  end

  test "a paragraph for a narrated game is the engine's refusal, in its words" do
    game = Playthrough::Session.begin!(@story).playthrough

    error = assert_raises(Playthrough::RustEngine::EngineError) do
      Playthrough::Session.new(game).write_paragraph!(game.current_scene, "You wait.")
    end
    assert_equal "wrong_mode", error.kind
    assert_empty Playthrough::Paragraph.all
  end

  test "a paragraph for a turn the game did not choose is refused, and nothing is kept" do
    game = begin_narrating

    error = assert_raises(Playthrough::RustEngine::EngineError) do
      Playthrough::Session.new(game).write_paragraph!(game.current_scene, "You wait.")
    end
    assert_equal "not_chosen", error.kind
    assert_empty Playthrough::Paragraph.all
  end

  test "a chosen turn waits, its card says what happened, and the paragraph is kept beside it" do
    game = begin_narrating
    session = Playthrough::Session.new(game)
    submission = session.act!
    finished = []

    scene = session.play(submission.command, request_token: submission.request_token,
                                             on_finish: ->(ending) { finished << ending })

    assert_equal [ [ nil, nil ] ], finished.map { |ending| [ ending.error, ending.refusal ] }
    assert_equal "engine", scene.resolved_by
    assert_equal scene, session.waiting
    card = session.facts_card(scene)
    assert_equal scene.id, card.scene
    assert card.act.present?

    assert_nil session.write_paragraph!(scene, "   "), "nothing written is not a paragraph"
    assert_equal scene, session.waiting

    paragraph = session.write_paragraph!(scene, "  #{card.act}  ")
    assert_equal card.act, paragraph.text
    assert_equal "player", paragraph.author
    assert_equal game, paragraph.playthrough
    assert_equal [], paragraph.notes
    assert_nil session.waiting
  end

  test "the check reads the paragraph in the scene's place and never saves it there" do
    game = begin_narrating
    session = Playthrough::Session.new(game)
    submission = session.act!
    scene = session.play(submission.command, request_token: submission.request_token)
    told = scene.description

    flags = Story::Audit.paragraph(scene, "#{@story.protagonist.fullname} looks about and")

    assert_equal %i[third_person_protagonist truncated_prose], flags.map(&:code).sort
    assert flags.all? { |flag| flag.contradiction? || flag.defect? }
    assert_equal told, scene.reload.description
  end

  private

  def begin_narrating = Playthrough::Session.begin!(@story, mode: "player_narrates").playthrough
end
