require "test_helper"

# Error reports to the owner's local command, through pocket-kit's errors piece
# as config/initializers/pocket_kit.rb sets it up. The gem's own tests cover the
# grouping, the field checks and the command run; these cover what this app
# configures -- the three sources reaching the command, the heading and the
# request-id prefix, the layout's meta tags -- and that with no command set the
# piece does nothing at all. The command is a script that records its
# arguments and stdin, so every test reads exactly what left the app.
class PocketKitErrorsTest < ActionDispatch::IntegrationTest
  class BrokenJob < ApplicationJob
    def perform(id)
      raise ArgumentError, "no ledger row #{id}"
    end
  end

  setup do
    PocketKit::ErrorsController::RATE_STORE.clear
    PocketKit::Errors.reset!
    @dir = Dir.mktmpdir
    @script = File.join(@dir, "fake-command")
    File.write(@script, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$@" > "$(dirname "$0")/args"
      cat > "$(dirname "$0")/stdin"
    SH
    File.chmod(0o755, @script)
    ENV["ERRORS_COMMAND"] = "#{@script} errors"

    @story = create(:story)
    @here = create(:location, story: @story, name: "The Lantern Market")
    @scene = create(:scene, story: @story, location: @here)
    @playthrough = create(:playthrough, story: @story, current_location: @here, current_scene: @scene)
  end

  teardown do
    PocketKit::Errors.flush
    ENV.delete("ERRORS_COMMAND")
    FileUtils.remove_entry(@dir)
  end

  def report
    PocketKit::Errors.flush
    path = File.join(@dir, "stdin")
    JSON.parse(File.read(path)) if File.exist?(path)
  end

  def args
    File.read(File.join(@dir, "args"))
  end

  # The test environment raises a request's exception into the test, and a
  # local request gets Rails' debug page, which Rails does not report; so the
  # production 500 page is what is turned on here.
  def break_the_index
    env = Rails.application.env_config
    previous = env.slice("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
    env.merge!("action_dispatch.show_exceptions" => :all, "action_dispatch.show_detailed_exceptions" => false)
    Story.stub(:includes, ->(*) { raise NoMethodError, "undefined method 'title' for nil" }) do
      get playthroughs_path
    end
  ensure
    env.merge!(previous)
  end

  def post_page_error
    post pocket_kit.errors_path, params: { kind: "error", class: "TypeError", message: "x is undefined",
                                           stack: "TypeError: x is undefined\n    at pin (/assets/application.js:3:9)",
                                           page: "/playthroughs/#{@playthrough.id}", screen: "playthroughs#show" },
                                 as: :json
  end

  test "a request that ends in a 500 reaches the command as a report" do
    break_the_index

    assert_response :internal_server_error
    sent = report
    assert_match(/\Aerrors\n--request-id\nta-errors-\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\n--json\n-\n\z/, args)
    assert_equal "Text adventure", sent["app"]
    assert_equal "request", sent["source"]
    assert_equal "NoMethodError", sent.dig("error", "class")
    assert sent["text"].start_with?("Text adventure error (source: request)\n\nNoMethodError:"), sent["text"]
  end

  test "an exception that escapes a job reaches the command, and the job still fails" do
    assert_raises(ArgumentError) { ActiveJob::Base.execute(BrokenJob.new(7).serialize) }

    sent = report
    assert_equal "job", sent["source"]
    assert_equal [ "Job: PocketKitErrorsTest::BrokenJob" ], sent["context"]
    assert_equal "no ledger row 7", sent.dig("error", "message")
  end

  test "an error the page posts reaches the command" do
    post_page_error

    assert_response :accepted
    sent = report
    assert_equal "browser", sent["source"]
    assert_equal "playthroughs#show", sent["screen"]
    assert_equal "/playthroughs/#{@playthrough.id}", sent["page"]
    assert_equal [ "at pin (/assets/application.js:3:9)" ], sent.dig("error", "backtrace")
  end

  # Not the button's owner-only gate: a player's page error is reported too.
  test "every page names where its errors go, for any player" do
    Playthrough::Debug.stub(:enabled?, false) { get playthrough_path(@playthrough) }

    assert_select "head meta[name=pocket-kit-errors][content=?]", pocket_kit.errors_path
    assert_select "head meta[name=pocket-kit-screen][content=?]", "playthroughs#show"
  end

  test "with no command set nothing is reported and nothing else changes" do
    ENV.delete("ERRORS_COMMAND")

    get playthrough_path(@playthrough)
    assert_response :success
    assert_select "meta[name=pocket-kit-errors]", count: 0

    break_the_index
    assert_response :internal_server_error

    post_page_error
    assert_response :not_found

    assert_raises(ArgumentError) { ActiveJob::Base.execute(BrokenJob.new(7).serialize) }
    assert_nil report
  end
end
