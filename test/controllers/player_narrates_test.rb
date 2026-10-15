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

  # THE EXISTING VERDICT BUTTONS JUDGE THE PLAYER'S PARAGRAPH: the same three
  # buttons under it, the same request, and a verdict frozen as the player's.
  # A rewrite clears it, because it judged other words.
  test "the verdict buttons under a kept paragraph judge the paragraph" do
    game = begin_narrating
    scene = act(game)
    post playthrough_paragraphs_path(game), params: { scene_id: scene.id, text: "You take it and turn it over." }
    paragraph = game.paragraphs.sole

    assert_equal "owner", paragraph.consent, "the browser's game is the owner's"
    assert_equal paragraph.act_request["prompt_digest"], paragraph.prompt_digest

    get playthrough_path(game)
    assert_select "##{ActionView::RecordIdentifier.dom_id(scene, :verdict)} form.marks[aria-label=?] input[name=verdict]",
                  "your verdict on your paragraph", count: Playthrough::Feedback::VERDICTS.size

    post playthrough_feedbacks_path(game), params: { scene_id: scene.id, verdict: "good" }, as: :turbo_stream
    assert_response :success
    assert_match(/your verdict on your paragraph/, response.body)
    feedback = game.feedbacks.find_by!(scene: scene)
    assert_predicate feedback, :player?
    assert_equal "good", feedback.verdict

    Playthrough::Session.new(game).write_paragraph!(scene, "You take it and turn it over.")
    assert game.feedbacks.exists?(scene: scene), "the same words keep their verdict"
    Playthrough::Session.new(game).write_paragraph!(scene, "You pocket it.")
    assert_not game.feedbacks.exists?(scene: scene), "a verdict on other words is cleared"
  end

  # THE ROOM IS REVEALED IN STEPS (the engine's noticed record): the card
  # names what the turn noticed and nothing the game has not, and a line naming
  # a thing not yet noticed is answered with the engine's refusal where the
  # turn would have been. The Furnished Rooms' study keeps a lump of coal in
  # its scuttle, which no tier but a search notices.
  #
  # THE LINE IS TYPED BEFORE THE GAME ACTS, in the room every game opens in.
  # The act is a die seeded off the story's and the playthrough's ids, which
  # depend on what this worker ran first, and some of its faces walk out of
  # the study; a line naming nothing in the room the player then stands in is
  # read by a model, which this suite has none of. The card holds for any act.
  test "the card names what the turn noticed, and a line naming an unnoticed thing is refused on the page" do
    story = WorldSeed::Loader.load_file(Rails.root.join("lib/engine_sweep/worlds/the-furnished-rooms.yml"))
    game = Playthrough::Session.begin!(story, mode: "player_narrates").playthrough

    perform_enqueued_jobs(only: NarrationJob) do
      post playthrough_turns_path(game), params: { command: "take the lump of coal", request_token: "coal-1" },
                                         as: :turbo_stream
    end
    assert_predicate game.items.find_by!(name: "lump of coal"), :lying?

    get playthrough_path(game)
    assert_select "p.command", "> take the lump of coal"
    assert_select ".notice p", /You have not noticed anything here by that name\. Look around the room first/
    assert_select ".notice p", text: /lump of coal/, count: 0

    scene = act(game)
    card = Playthrough::Session.new(game).facts_card(scene)

    get playthrough_path(game)
    assert_select ".facts-card", text: /lump of coal/, count: 0
    if card.noticed.any?
      assert_select ".facts-card .sheet-note", "Noticed this turn: #{card.noticed.join(", ")}."
    else
      assert_select ".facts-card .sheet-note", text: /Noticed this turn/, count: 0
    end
  end

  private

  def begin_narrating = Playthrough::Session.begin!(@story, mode: "player_narrates").playthrough

  def act(game)
    session = Playthrough::Session.new(game)
    submission = session.act!
    session.play(submission.command, request_token: submission.request_token)
  end
end
