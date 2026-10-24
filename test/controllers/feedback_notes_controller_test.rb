require "test_helper"

# A note to the maintainer, handed to the command `FEEDBACK_COMMAND` names. The
# command here is a script that records its arguments and stdin, so every test
# reads exactly what left the app.
class FeedbackNotesControllerTest < ActionDispatch::IntegrationTest
  REQUEST_ID = "0b6f1c1e-6a51-4d6a-9d3e-3f3a0c2e9b11".freeze

  setup do
    FeedbackNotesController::RATE_STORE.clear
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

  def send_note(text: "The exits are hard to read", screen: "playthroughs#show", request_id: REQUEST_ID, **extra)
    post feedback_note_path, params: { text: text, screen: screen, request_id: request_id, **extra }, as: :turbo_stream
  end

  def recorded(name)
    path = File.join(@dir, name)
    File.read(path) if File.exist?(path)
  end

  test "runs the command with the request id as arguments and the note on stdin" do
    send_note

    assert_response :success
    assert_includes response.body, "Sent"
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

  test "what the browser reports about the device follows the note as a Device block" do
    send_note(device: { user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", screen: "390x844",
                        viewport: "390x664", visual_viewport: "390x664", pixel_ratio: "3",
                        standalone: "true", color_scheme: "dark" })

    assert_equal "Text adventure feedback (screen: playthroughs#show)\n\nThe exits are hard to read\n\n" \
                 "Device:\nBrowser: Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)\nScreen: 390x844\n" \
                 "Viewport: 390x664\nVisual viewport: 390x664\nPixel ratio: 3\nHome screen app: true\n" \
                 "Colour scheme: dark\n", recorded("stdin")
  end

  test "a device value that is malformed, overlong or unknown is dropped, and the note is still sent" do
    send_note(device: { user_agent: "a" * 301, screen: "390x844\nRoom: forged", viewport: "wide",
                        pixel_ratio: "2.5", standalone: "maybe", color_scheme: "sepia", token: "secret" })

    assert_response :success
    assert_equal "Text adventure feedback (screen: playthroughs#show)\n\nThe exits are hard to read\n\n" \
                 "Device:\nPixel ratio: 2.5\n", recorded("stdin")
  end

  test "a device param that is not a set of fields is ignored" do
    send_note(device: "390x844")

    assert_response :success
    assert_equal "Text adventure feedback (screen: playthroughs#show)\n\nThe exits are hard to read\n", recorded("stdin")
  end

  test "shell metacharacters in the variable stay literal arguments" do
    marker = File.join(@dir, "SHELL_RAN")
    ENV["FEEDBACK_COMMAND"] = "#{@script} ';' touch #{marker}"
    send_note

    assert_response :success
    assert_equal ";\ntouch\n#{marker}\n--request-id\nta-feedback-#{REQUEST_ID}\n--json\n-\n", recorded("args")
    assert_not File.exist?(marker)
  end

  test "a failing command is reported as a failure, not as sent" do
    ENV["FAKE_EXIT"] = "3"
    send_note

    assert_response :unprocessable_content
    assert_includes response.body, "Couldn't send"
    assert_not_includes response.body, "Sent"
  end

  test "a missing command is reported as a failure" do
    ENV["FEEDBACK_COMMAND"] = File.join(@dir, "missing")
    send_note

    assert_response :unprocessable_content
  end

  test "is not found when no command is configured" do
    ENV.delete("FEEDBACK_COMMAND")
    send_note

    assert_response :not_found
    assert_nil recorded("stdin")
  end

  test "is not found for anyone but the owner" do
    Playthrough::Debug.stub(:enabled?, false) { send_note }

    assert_response :not_found
    assert_nil recorded("stdin")
  end

  test "rejects an empty note and one over the length cap" do
    send_note(text: "   ")
    assert_response :unprocessable_content

    send_note(text: "a" * (FeedbackNotesController::MAX_LENGTH + 1))
    assert_response :unprocessable_content
    assert_nil recorded("stdin")
  end

  test "rejects an unknown screen and a malformed request id" do
    send_note(screen: "playthroughs#secret")
    assert_response :unprocessable_content

    send_note(request_id: "not-a-uuid")
    assert_response :unprocessable_content
    assert_nil recorded("stdin")
  end

  test "more than five notes in a minute are refused" do
    FeedbackNotesController::NOTES_PER_MINUTE.times { send_note }
    File.delete(File.join(@dir, "stdin"))

    send_note
    assert_response :unprocessable_content
    assert_nil recorded("stdin")
  end

  test "the button is shown to the owner only when a command is configured" do
    get playthrough_path(@playthrough)
    assert_select "dialog.feedback-dialog"
    assert_select "#feedback input[name=playthrough_id][value=?]", @playthrough.id.to_s
    assert_select "#feedback input[name=screen][value=?]", "playthroughs#show"

    Playthrough::Debug.stub(:enabled?, false) { get playthrough_path(@playthrough) }
    assert_select "#feedback", count: 0

    ENV.delete("FEEDBACK_COMMAND")
    get playthrough_path(@playthrough)
    assert_select "#feedback", count: 0
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
    fields = css_select("#feedback form input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }
    FeedbackNotesController::DEVICE_FIELDS.each_key do |field|
      assert_select "#feedback form input[name=?][data-feedback-target=device][data-field=?]", "device[#{field}]", field.to_s
    end
    fields["device[screen]"] = "390x844" # as the dialog's script fills it in

    post feedback_note_path, params: fields.merge("text" => "Exits could be links"), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=replace][target=feedback] .feedback-sent", text: "Sent"
    assert_includes recorded("stdin"), "Room: The Lantern Market\n\nExits could be links\n\nDevice:\nScreen: 390x844\n"
  end
end
