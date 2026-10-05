# A TEST THAT PLAYS A TURN, PLAYED ON THE RUST ENGINE.
#
# The engine plays every turn on a connection of its own, so it can neither see
# into nor write past the transaction an ordinary test runs in
# (`Playthrough::RustEngine.unplayable` refuses one). A test class that
# includes this runs each test, its own `setup` included, on a scratch copy of
# this worker's database instead -- the same copy `EngineSweep::Parity::InProcess`
# walks a sweep script on: a handler of its own, connected to a file in a
# directory that is deleted when the test is done, and exempt from the
# suite's transaction (`skip_transactional_tests_for_database`, in
# test/test_helper.rb). So every row a test writes is committed where the
# engine reads it, and none of it outlives the test.
#
# NO MODEL. A turn that asks one is answered by `#replying`, in the declared
# order, through the engine's own replay (`Playthrough::RustEngine.replaying`),
# exactly as a sweep script's browser step is; a turn handed no replies runs
# keyless, as the suite does everywhere.
module PlaysOnRust
  extend ActiveSupport::Concern

  # What a classification that is not a move or an act answers.
  NOT_A_MOVE = { "intent" => "other", "target" => "nothing", "also_named" => "nothing" }.freeze

  included do
    # Registered before the class's own `setup`, so the rows it creates are
    # written to the copy.
    setup :play_on_a_scratch_copy
    teardown :leave_the_scratch_copy
  end

  # One reply the engine's replay answers a call with: `purpose` is the call's
  # (`classifier`, `narration`, `arrival`, `character`, ...) and `content` what
  # the provider says. `failure:` fails the call instead, as a provider fails
  # one -- a kind (`crisis`, `no_model`, `unauthorized`, `refused`,
  # `provider`, ...) and the message it fails with -- and `unavailable: true`
  # is a provider that cannot be reached. `includes:`/`excludes:` are what the
  # request the engine built must and must not say.
  def reply(purpose, content = nil, failure: nil, message: "", unavailable: false, includes: nil, excludes: nil)
    { "purpose" => purpose.to_s, "content" => content, "unavailable" => (true if unavailable),
      "failure" => ({ "kind" => failure.to_s, "message" => message } if failure),
      "prompt_includes" => includes, "prompt_excludes" => excludes }.compact
  end

  # Runs the block with the engine answering its model calls from `replies`,
  # and fails the test unless the turn asked exactly those, in order, and every
  # prompt said what its reply asked of it. Returns the block's value.
  def replying(*replies)
    replayed = nil
    value = Playthrough::RustEngine.replaying(replies) do
      yield
    ensure
      replayed = Playthrough::RustEngine.replayed
    end
    assert_nil replayed&.dig("unfinished"), "the engine's replay did not finish cleanly"
    value
  end

  private

  def play_on_a_scratch_copy
    @scratch_directory = Dir.mktmpdir("plays-on-rust", Rails.root.join("tmp"))
    file = File.join(@scratch_directory, "test.sqlite3")
    EngineSweep::Parity.copy_database!(file)
    @suite_handler = ActiveRecord::Base.connection_handler
    ActiveRecord::Base.connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    ActiveRecord::Base.establish_connection(
      ActiveRecord::DatabaseConfigurations::HashConfig.new(Rails.env, EngineSweep::Parity::SCRATCH,
                                                           { adapter: "sqlite3", database: file })
    )
  end

  def leave_the_scratch_copy
    ActiveRecord::Base.connection_handler.clear_all_connections!
    ActiveRecord::Base.connection_handler = @suite_handler if @suite_handler
    FileUtils.rm_rf(@scratch_directory) if @scratch_directory
  end
end
