require "test_helper"

# THE BROWSER'S HALF OF A GAME THE PLAYER NARRATES: the mode chosen at Play,
# the "let the game act" button, the facts card and the paragraph box, and the
# paragraph and its note in the log. Every decision is `Playthrough::Session`'s
# (`Playthrough::PlayerNarratesTest`); these hold the requests and the page.
class PlayerNarratesControllerTest < ActionDispatch::IntegrationTest
  include PlaysOnRust
  include ActiveJob::TestHelper

  setup do
    @story = WorldSeed::Loader.load_file(Rails.root.join("db/seeds/worlds/the-salt-assizes.yml"))
  end

  test "Play offers the mode, narrated already chosen" do
    get root_path

    assert_select "form.play-mode input[type=radio][name=mode][value=narrated][checked]"
    assert_select "form.play-mode input[type=radio][name=mode][value=player_narrates]:not([checked])"
  end

  test "Play starts the game in the mode chosen, and in narrated for none or one it does not know" do
    post playthroughs_path, params: { story_id: @story.id, mode: "player_narrates" }
    assert_equal "player_narrates", Playthrough.last.mode

    post playthroughs_path, params: { story_id: @story.id }
    assert_equal "narrated", Playthrough.last.mode

    post playthroughs_path, params: { story_id: @story.id, mode: "sung" }
    assert_equal "narrated", Playthrough.last.mode
  end

  test "a game the player narrates has the act button where the box was" do
    game = begin_narrating

    get playthrough_path(game)

    assert_select "form[action=?] input[type=submit][value=?]", act_playthrough_turns_path(game), "Let the game act"
    assert_select "input[name=command][type=text]", count: 0
    assert_select ".facts-card", count: 0
  end

  test "a narrated game keeps its box and has no act button" do
    game = Playthrough::Session.begin!(@story).playthrough

    get playthrough_path(game)

    assert_select "input[name=command][type=text]"
    assert_select "form[action=?]", act_playthrough_turns_path(game), count: 0
  end

  test "letting the game act hands the engine's line to the job, as a typed line is handed" do
    game = begin_narrating

    assert_enqueued_with job: NarrationJob, args: [ game.id, Playthrough::RustEngine::ACT_LINE, "act-1" ] do
      post act_playthrough_turns_path(game), params: { request_token: "act-1" }, as: :turbo_stream
    end
    assert_response :success
    assert_match(/request-token/, response.body)
  end

  test "the job plays the game's act, and the turn waits for the paragraph" do
    game = begin_narrating

    perform_enqueued_jobs(only: NarrationJob) do
      post act_playthrough_turns_path(game), params: { request_token: "act-1" }, as: :turbo_stream
    end

    command = game.commands.sole
    assert_predicate command, :completed?
    assert_equal "engine", command.result_scene.resolved_by
    assert_equal command.result_scene, Playthrough::Session.new(game).waiting
  end

  test "a narrated game told to act takes nothing" do
    game = Playthrough::Session.begin!(@story).playthrough

    assert_no_enqueued_jobs do
      post act_playthrough_turns_path(game), params: { request_token: "act-1" }
    end
    assert_redirected_to playthrough_path(game)
    assert_empty game.commands
  end

  test "the turn the game chose shows its card and the box, and a kept paragraph shows in the log with its note" do
    game = begin_narrating
    scene = act(game)

    get playthrough_path(game)
    assert_select ".facts-card h2", "What happened"
    assert_select ".facts-card .sheet-lead", Playthrough::Session.new(game).facts_card(scene).act
    assert_select ".facts-card form[action=?] textarea[name=text]", playthrough_paragraphs_path(game)
    assert_select ".facts-card input[name=scene_id][value=?]", scene.id.to_s

    post playthrough_paragraphs_path(game), params: { scene_id: scene.id, text: "You stand there and" }
    assert_redirected_to playthrough_path(game, anchor: "bottom")

    paragraph = game.paragraphs.sole
    assert_equal "You stand there and", paragraph.text
    get playthrough_path(game)
    assert_select ".facts-card", count: 0
    assert_select "##{ActionView::RecordIdentifier.dom_id(paragraph)}", "You stand there and"
    assert_select ".entry .notice", /stops mid-sentence/
  end

  test "a paragraph for a turn the game did not choose is not kept, and the page says why" do
    game = begin_narrating

    post playthrough_paragraphs_path(game), params: { scene_id: game.current_scene_id, text: "You wait." }

    assert_redirected_to playthrough_path(game, anchor: "bottom")
    assert_match(/That paragraph was not kept/, flash[:alert])
    assert_empty game.paragraphs
  end

  private

  def begin_narrating = Playthrough::Session.begin!(@story, mode: "player_narrates").playthrough

  def act(game)
    session = Playthrough::Session.new(game)
    submission = session.act!
    session.play(submission.command, request_token: submission.request_token)
  end
end
