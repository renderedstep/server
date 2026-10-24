require "test_helper"

# A note to the maintainer, through pocket-kit's feedback endpoint as
# config/initializers/pocket_kit.rb sets it up. The gem's own tests cover the
# command run, the device block and the checks; these cover what this app
# configures -- the owner-only gate, the heading, the request-id prefix, the
# playthrough and room lines -- and the layout that shows it. The command is a
# script that records its arguments and stdin, so every test reads exactly what
# left the app.
class PocketKitFeedbackTest < ActionDispatch::IntegrationTest
  REQUEST_ID = "0b6f1c1e-6a51-4d6a-9d3e-3f3a0c2e9b11".freeze

  setup do
    PocketKit::FeedbackController::RATE_STORE.clear
    @dir = Dir.mktmpdir
    @script = File.join(@dir, "fake-command")
    File.write(@script, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$@" > "$(dirname "$0")/args"
      cat > "$(dirname "$0")/stdin"
      exit "${FAKE_EXIT:-0}"
    SH
    File.chmod(0o755, @script)
    @previous = ENV.fetch("FEEDBACK_COMMAND", nil)
    ENV["FEEDBACK_COMMAND"] = "#{@script} send"

    @story = create(:story)
    @here = create(:location, story: @story, name: "The Lantern Market")
    @scene = create(:scene, story: @story, location: @here, description: "Stalls stand under wet canvas.")
    @playthrough = create(:playthrough, story: @story, current_location: @here, current_scene: @scene)
  end

  teardown do
    ENV["FEEDBACK_COMMAND"] = @previous
    ENV.delete("FAKE_EXIT")
    FileUtils.remove_entry(@dir)
  end

  def send_note(text: "The exits are hard to read", screen: "playthroughs#show", **extra)
    post pocket_kit.feedback_path, params: { text: text, screen: screen, request_id: REQUEST_ID, **extra },
                                   as: :turbo_stream
  end

  def recorded(name)
    path = File.join(@dir, name)
    File.read(path) if File.exist?(path)
  end

  test "the note carries the game's heading and the command gets the game's request-id prefix" do
    send_note

    assert_response :success
    assert_equal "send\n--request-id\nta-feedback-#{REQUEST_ID}\n--json\n-\n", recorded("args")
    assert_equal "Text adventure feedback (screen: playthroughs#show)\n\nThe exits are hard to read\n", recorded("stdin")
  end

  test "on a game screen the room's name and the playthrough's id ride along, and nothing else of the game" do
    send_note(playthrough_id: @playthrough.id)

    stdin = recorded("stdin")
    assert_equal "Text adventure feedback (screen: playthroughs#show)\nPlaythrough: #{@playthrough.id}\n" \
                 "Room: The Lantern Market\n\nThe exits are hard to read\n", stdin
    assert_not_includes stdin, "wet canvas"
    assert_not_includes stdin, @playthrough.token
    assert_not_includes stdin, @story.title
  end

  test "an unknown playthrough adds no lines" do
    send_note(playthrough_id: "999999")

    assert_equal "Text adventure feedback (screen: playthroughs#show)\n\nThe exits are hard to read\n", recorded("stdin")
  end

  # Exit 3 is the command saying it saved the note but has not announced it yet.
  test "exit 3 is sent, any other failure is not" do
    ENV["FAKE_EXIT"] = "3"
    send_note
    assert_response :success
    assert_includes response.body, "Sent"

    ENV["FAKE_EXIT"] = "1"
    send_note
    assert_response :unprocessable_content
    assert_select "turbo-stream[target=pocket_kit_feedback_status] .pk-feedback-failed", text: /Couldn't send/
  end

  test "is not found for anyone but the owner" do
    Playthrough::Debug.stub(:enabled?, false) { send_note }

    assert_response :not_found
    assert_nil recorded("stdin")
  end

  test "the button is shown to the owner only when a command is configured" do
    get playthrough_path(@playthrough)
    assert_select "header.page-header #pocket_kit_feedback dialog.pk-feedback-dialog"
    assert_select "#pocket_kit_feedback input[name=playthrough_id][value=?]", @playthrough.id.to_s
    assert_select "#pocket_kit_feedback input[name=screen][value=?]", "playthroughs#show"
    assert_select "#pocket_kit_feedback textarea[placeholder=?]", "What would make the game better?"

    Playthrough::Debug.stub(:enabled?, false) { get playthrough_path(@playthrough) }
    assert_select "#pocket_kit_feedback", count: 0

    ENV.delete("FEEDBACK_COMMAND")
    get playthrough_path(@playthrough)
    assert_select "#pocket_kit_feedback", count: 0
  end

  # The loading screen is the body's first child and `#ready` its last, which is
  # the whole of what the layout's inline `:has()` rule reads to hide it.
  test "every page opens with the loading screen and ends with the marker that hides it" do
    get playthrough_path(@playthrough)
    assert_select "body > div.loading:first-child[role=status]"
    assert_select "head style", count: 1
    assert_select "body > style", count: 1
    assert_select "body > #ready:last-child"
  end

  # The whole round trip a click makes: the page's own form, posted as it
  # stands, answered with a stream that closes the dialog and says "Sent".
  test "the form on the page posts what the page carries" do
    get playthrough_path(@playthrough)
    action = css_select("#pocket_kit_feedback form").first["action"]
    fields = css_select("#pocket_kit_feedback form input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }
    fields["device[screen]"] = "390x844" # as the dialog's script fills it in

    post action, params: fields.merge("text" => "Exits could be links"), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=replace][target=pocket_kit_feedback] .pk-feedback-sent", text: "Sent"
    assert_includes recorded("stdin"), "Room: The Lantern Market\n\nExits could be links\n\nDevice:\nScreen: 390x844\n"
  end
end
