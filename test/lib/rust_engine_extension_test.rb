require "test_helper"

# THE REAL EXTENSION, when it is built (`bin/rails engine:build`); skipped
# otherwise. CI's test job builds it before the suite runs, and the engine
# sweep (`test/lib/engine_sweep_test.rb`) fails outright without it.
class RustEngineExtensionTest < ActiveSupport::TestCase
  # The engine reads what Ruby committed, on scratch copies of this database,
  # so nothing here may sit inside the suite's transaction.
  self.use_transactional_tests = false

  setup do
    skip "the Rust engine's extension is not built (bin/rails engine:build)" if Playthrough::RustEngine.extension.nil?
  end

  test "it opens this schema" do
    database = File.expand_path(ApplicationRecord.connection_db_config.database, Rails.root)
    answer = JSON.parse(RenderedStep.play(database, 0, "/look", nil))

    assert_equal "no_such_playthrough", answer.dig("error", "kind"), answer.inspect
    assert_operator ActiveRecord::Base.connection_pool.migration_context.current_version.to_s, :>=, RenderedStep::SCHEMA_VERSION
  end

  test "the line that lets the game act is the engine's own" do
    assert_equal RenderedStep::ACT_LINE, Playthrough::RustEngine::ACT_LINE
  end

  test "every failure is an answer, never an exception or a panic" do
    missing = JSON.parse(RenderedStep.submit("/nonexistent/game.sqlite3", 1, "/look", "t", "{}"))
    assert_equal "database", missing.dig("error", "kind")

    garbled = JSON.parse(RenderedStep.submit("/nonexistent/game.sqlite3", 1, "/look", "t", "not json"))
    assert_equal "panicked", garbled.dig("error", "kind")

    assert_equal "database", JSON.parse(RenderedStep.play("/nonexistent/game.sqlite3", 1, "/look", nil)).dig("error", "kind")
    assert_equal "database", JSON.parse(RenderedStep.act("/nonexistent/game.sqlite3", 1, "t", false, "{}")).dig("error", "kind")
    assert_equal "database", JSON.parse(RenderedStep.facts_card("/nonexistent/game.sqlite3", 1, 1)).dig("error", "kind")
    assert_equal "database", JSON.parse(RenderedStep.write_paragraph("/nonexistent/game.sqlite3", 1, 1, "x", "owner")).dig("error", "kind")
    assert_equal "unsupported", JSON.parse(RenderedStep.write_paragraph("/nonexistent/game.sqlite3", 1, 1, "x", "everyone")).dig("error", "kind")
    assert_equal "database", JSON.parse(RenderedStep.noticed_findings("/nonexistent/game.sqlite3", 1)).dig("error", "kind")
    assert_equal "database", JSON.parse(RenderedStep.start("/nonexistent/game.sqlite3", 1, "player_narrates")).dig("error", "kind")
    assert_equal "unsupported", JSON.parse(RenderedStep.start("/nonexistent/game.sqlite3", 1, "sung")).dig("error", "kind")
  end

  test "a script walked on the Rust engine passes every gate" do
    script = EngineSweep.scripts.find { |candidate| candidate.name == "a-thing-can-be-thrown" }

    assert_equal [ [] ], EngineSweep::RustGates.check([ script ]).map(&:problems)
  end

  test "a newer schema that changes a table the engine writes is refused in the engine's words" do
    script = EngineSweep.scripts.find { |candidate| candidate.name == "a-thing-can-be-thrown" }
    before = Playthrough::RustEngine.failures.fetch("schema_changed", 0)
    finished = []

    Dir.mktmpdir do |directory|
      file = File.join(directory, "newer.sqlite3")
      EngineSweep::Parity.copy_database!(file)
      engine = EngineSweep::Parity::InProcess.new(:rust)
      error = assert_raises(Playthrough::RustEngine::EngineError) do
        engine.on_file(file) do
          walk = EngineSweep::Walk.new(script)
          walk.prepare!
          ActiveRecord::Base.connection.execute("INSERT INTO schema_migrations (version) VALUES ('99990101000000')")
          # A trigger on a table the engine writes, which it would not know fires.
          ActiveRecord::Base.connection.execute(<<~SQL)
            CREATE TRIGGER a_newer_rule AFTER INSERT ON playthrough_commands BEGIN SELECT 1; END
          SQL
          game = walk.game_of(script.steps.first.player)
          Playthrough::RustEngine.replaying([]) do
            Playthrough::Session.new(game).play("/look", request_token: "newer-schema", on_finish: ->(ending) { finished << ending })
          end
        end
      end

      assert_equal "schema_changed", error.kind
    end
    assert_match "a_newer_rule", finished.sole.error
    assert_equal before + 1, Playthrough::RustEngine.failures["schema_changed"]
  end

  # A BREAK DIE IS A ROLL, read off the receipt the engine keeps in the turn's
  # journal: the brittle tar pot thrown at the shed's door comes down on a
  # floor, short of the door or through it, and throws the break die, and the
  # finish reports its face against the share it breaks on, broken at or
  # under it.
  test "a break die the engine threw is one of the turn's rolls" do
    script = EngineSweep.scripts.find { |candidate| candidate.name == "a-throw-can-fall-short" }
    walked = script.steps.select { |step| step.id == "into-the-ropewalk" }

    Dir.mktmpdir do |directory|
      file = File.join(directory, "rolls.sqlite3")
      EngineSweep::Parity.copy_database!(file)
      EngineSweep::Parity::InProcess.new(:rust).on_file(file) do
        walk = EngineSweep::Walk.new(script)
        walk.prepare!
        walked.each { |step| walk.play_step(step) }
        game = walk.game_of(walked.sole.player)
        Playthrough::RustEngine.replaying([]) do
          Playthrough::Session.new(game).play("/throw tar pot at The Tarring Shed", request_token: "rolls")
        end
        command = game.commands.find_by!(request_token: "rolls")

        rolled = Protocol::V1.rolls(command, command.result_scene).select { |roll| roll[:kind] == "break" }
        assert_equal 1, rolled.size, command.journal.inspect
        assert_equal 6, rolled.sole[:die]
        pot = game.items.find_by!(name: "tar pot")
        assert_equal rolled.sole[:result] <= rolled.sole[:target], pot.disposition == "broken"
      end
    end
  end

  # A CHECK IS A ROLL TOO. A throw makes its thrower's strength check before
  # anything lands, and the engine keeps that check's receipt in the turn's
  # `checks` journal step; the finish reports its d20 against the target, and
  # ahead of the break die, as `Protocol::V1#rolls` orders them.
  test "a check the engine threw is one of the turn's rolls" do
    script = EngineSweep.scripts.find { |candidate| candidate.name == "a-throw-can-fall-short" }
    walked = script.steps.select { |step| step.id == "into-the-ropewalk" }

    Dir.mktmpdir do |directory|
      file = File.join(directory, "checks.sqlite3")
      EngineSweep::Parity.copy_database!(file)
      EngineSweep::Parity::InProcess.new(:rust).on_file(file) do
        walk = EngineSweep::Walk.new(script)
        walk.prepare!
        walked.each { |step| walk.play_step(step) }
        game = walk.game_of(walked.sole.player)
        Playthrough::RustEngine.replaying([]) do
          Playthrough::Session.new(game).play("/throw tar pot at The Tarring Shed", request_token: "checks")
        end
        command = game.commands.find_by!(request_token: "checks")

        rolled = Protocol::V1.rolls(command, command.result_scene)
        assert_equal "check", rolled.first[:kind], command.journal.inspect
        check = rolled.select { |roll| roll[:kind] == "check" }.sole
        assert_equal Character::CHECK_DIE, check[:die]
        assert_includes 1..Character::CHECK_DIE, check[:result]
        assert_kind_of Integer, check[:target]
      end
    end
  end

  # THE CLASSIFIER'S LOCAL READER, over a real socket, with the live models
  # document a turn builds from the environment: the engine posts its request
  # to the address, names the weights by digest, and plays what comes back. No
  # address is the reader down, refused in the engine's words, and never a
  # model call: there is no key here, so a model call would fail the turn.
  test "a free-typed line is read by the local reader at its address, and refused without one" do
    script = EngineSweep.scripts.find { |candidate| candidate.name == "two-readers-of-one-typed-line" }
    posted = Queue.new
    reader = TCPServer.new("127.0.0.1", 0)
    answering = Thread.new do
      loop do
        client = reader.accept
        head = +""
        head << client.gets until head.end_with?("\r\n\r\n")
        request = JSON.parse(client.read(head[/content-length: (\d+)/i, 1].to_i))
        posted << request
        # Every question answered, as the model does: a take it reads as absent.
        answers = request.fetch("questions").to_h do |id, question|
          next [ id, { type: "noul", noul: id == "target_present" ? 0.04 : 0.0 } ] if question["type"] == "noul"

          [ id, { type: "choice", choice: id == "intent" ? "take" : "nothing" } ]
        end
        body = { answers: answers, usage: { cost: 0 } }.to_json
        client.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}")
        client.close
      end
    end

    Dir.mktmpdir do |directory|
      file = File.join(directory, "local.sqlite3")
      EngineSweep::Parity.copy_database!(file)
      File.binwrite(File.join(directory, "pointer.pt"), "weights")
      EngineSweep::Parity::InProcess.new(:rust).on_file(file) do
        walk = EngineSweep::Walk.new(script)
        walk.prepare!
        game = walk.game_of(script.steps.first.player)

        with_reader("http://127.0.0.1:#{reader.addr[1]}/", directory) do
          refusal = Playthrough::RustEngine.submit(game, "take the brass key", "absent")["turned"]["refusal"]
          assert_equal "unresolved", refusal["kind"], refusal.inspect
          assert_includes refusal["offer"], "red coin"
        end
        request = posted.pop
        assert_equal "pointer-#{Digest::SHA256.hexdigest("weights").first(16)}", request["model"]
        assert_equal "take the brass key", request.dig("state", "player_action")

        with_reader(nil, directory) do
          refusal = Playthrough::RustEngine.submit(game, "take the brass key", "down")["turned"]["refusal"]
          assert_equal "unreadable", refusal["kind"]
          assert_match(/slash menu lists them/, refusal["fact"])
        end
      end
    end
  ensure
    answering&.kill
    reader&.close
  end

  # TWO COPIES OF SQLITE IN ONE PROCESS, the `sqlite3` gem's and the
  # extension's, on one file in write-ahead-log mode. The engine's connection
  # closing must leave the log to this process's own connection: a checkpoint
  # on close deleted it, and the write Ruby made next went into a file no other
  # connection could see.
  test "what Ruby writes after the engine has closed on the file is what everybody reads" do
    script = EngineSweep.scripts.find { |candidate| candidate.name == "a-thing-can-be-thrown" }

    Dir.mktmpdir do |directory|
      file = File.join(directory, "shared.sqlite3")
      EngineSweep::Parity.copy_database!(file)
      EngineSweep::Parity::InProcess.new(:rust).on_file(file) do
        walk = EngineSweep::Walk.new(script)
        walk.prepare!
        game = walk.game_of(script.steps.first.player)
        assert_equal "wal", ActiveRecord::Base.connection.select_value("PRAGMA journal_mode")

        Playthrough::RustEngine.play(game, "/look")
        game.update!(updated_at: Time.utc(2031, 1, 2, 3, 4, 5))

        other = SQLite3::Database.new(file, readonly: true)
        assert_equal "2031-01-02 03:04:05", other.get_first_value("SELECT updated_at FROM playthroughs WHERE id = ?", game.id).to_s[0, 19]
        other.close
      end
    end
  end

  test "a glance is read off a copy, and leaves the file as it found it" do
    script = EngineSweep.scripts.find { |candidate| candidate.name == "a-thing-can-be-thrown" }

    Dir.mktmpdir do |directory|
      file = File.join(directory, "glanced.sqlite3")
      EngineSweep::Parity.copy_database!(file)
      EngineSweep::Parity::InProcess.new(:rust).on_file(file) do
        walk = EngineSweep::Walk.new(script)
        walk.prepare!
        game = walk.game_of(script.steps.first.player)
        before = Dir.children(directory).sort

        glance = Playthrough::Session.new(game).glance
        assert_equal game.current_location.name, glance.room.name
        assert_equal before, Dir.children(directory).sort
      end
    end
  end

  private

  # A live models document, which the sweep's guard refuses: with no key in
  # the suite's environment it names no model, only the local reader.
  def with_reader(url, weights)
    saved = ENV.to_h.slice("POINTER_CLASSIFIER_URL", "POINTER_CLASSIFIER_WEIGHTS")
    guard = Playthrough::RustEngine.live_models_guard
    Playthrough::RustEngine.live_models_guard = nil
    url ? ENV["POINTER_CLASSIFIER_URL"] = url : ENV.delete("POINTER_CLASSIFIER_URL")
    ENV["POINTER_CLASSIFIER_WEIGHTS"] = weights
    assert_not_predicate Playthrough::RustEngine, :model_configured?
    yield
  ensure
    Playthrough::RustEngine.live_models_guard = guard
    ENV.delete("POINTER_CLASSIFIER_URL")
    ENV.delete("POINTER_CLASSIFIER_WEIGHTS")
    ENV.update(saved)
  end
end
