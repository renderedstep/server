# THE RUST ENGINE, AND EVERYTHING RUBY KNOWS ABOUT IT.
#
# The Rust engine (https://github.com/renderedstep/engine) plays the game:
# `Playthrough::Session#play` hands it every whole turn through a native
# extension (`ext/renderedstep`), so every front end -- the browser, the API,
# anything else that plays through the session -- plays on Rust, and what a
# front end shows between turns is read off it too (`.glance`, `.scaffold`).
# Turbo, the labs, the benches, the doctor, repair, seeding and every backfill
# stay Ruby, on the same database. README.md ("The Rust engine") says how to
# build it; a checkout cannot play without it.
#
# THERE IS NO FALLBACK. A turn the engine cannot play fails, in the engine's
# own words, and is never played again on Ruby behind the player's back:
# `EngineError` carries the words, `Playthrough::Session.ending_for` shows them
# as the turn's failure notice, and `.failed!` logs and counts it. That covers
# an extension that is not built or does not load, a database transaction left
# open around the call (SQLite has one writer, and the engine writes on its own
# connection), and every error the engine answers with: a schema it is not
# written against, a rule it does not play yet, a database failure, a panic it
# caught.
#
# A MODEL FAILURE IS HOW A TURN ENDED, not an engine error. It is raised as the
# Ruby app's own exception for it (`.exception_for`), so the player is told what
# they have always been told: the crisis notice, the setup notice, the failure
# copy.
#
# THE RUBY TURN LOOP IS KEPT UNTIL ITS TESTS HAVE COUNTERPARTS, and nothing
# plays it but them. `Playthrough::Turn` stays in the code while its own tests
# still run (test/ruby_loop_coverage.yml names, for each, the check that holds
# the Rust engine to the same behaviour), and `.using(:ruby)` plays it for one
# block -- for asking by hand where the two loops part. No setting turns it on
# for a player, and the test suite plays Rust.
#
# THE CREDENTIALS ARE THE ONES RUBY USES. `.models` reads `OPENROUTER_API_KEY`
# (the Direct route), `OPENROUTER_MODEL`, and the System One keys exactly as
# `BaseAgent` and `SystemOneAgent` do, and hands them over as one document.
# Nothing here logs that document, and the engine keeps a key as a value that
# cannot be printed. The local rotation (`TA_LOCAL_MODELS`) is Ruby's alone, so
# it never reaches a turn.
module Playthrough::RustEngine
  # Where `bin/rails engine:build` leaves the extension; `require` adds the
  # platform's own suffix.
  EXTENSION = Rails.root.join("ext/renderedstep/build/renderedstep_native").to_s

  ENGINES = %i[rust ruby].freeze

  # THE LINE A SUBMISSION CARRIES WHEN THE PLAYER LETS THE GAME ACT, in a game
  # the player narrates: the engine's own (`chooser::LINE`, which the extension
  # answers as `RenderedStep::ACT_LINE`), copied here so a page can be drawn
  # without the extension loaded. In any other game it is a typed line like any
  # other.
  ACT_LINE = "(the game acts)"

  # A turn the engine could not play, in its own words. `kind` is the engine's
  # name for the error (`unsupported`, `database`, ...), or `not_built` and
  # `transaction_open` for the two this side finds before asking it.
  class EngineError < StandardError
    attr_reader :kind

    def initialize(kind, message)
      @kind = kind.to_s
      super(message)
    end

    # What the player reads.
    def notice = "The engine could not play that turn: #{message}"
  end

  # A model call failed after the rotation was exhausted, in a way the Ruby
  # app has no exception class of its own for.
  class ModelFailed < StandardError; end

  # A replayed provider a sweep step declared unavailable.
  class ProviderUnavailable < ModelFailed; end

  # A replayed call nobody declared, or one out of order.
  class ReplayMismatch < ModelFailed; end

  # The turn was stopped after a named journal step, as a killed worker stops.
  # An `Interrupt`, as the sweep's own stopped worker is, so nothing that
  # rescues a StandardError mistakes it for a failed turn.
  class Stopped < Interrupt; end

  FAILURES = Concurrent::Map.new

  # Which engine plays a turn: Rust, unless this thread is playing the Ruby
  # reference.
  def self.engine = Thread.current[:turn_engine] || :rust

  # Plays the block on one engine, for this thread: a test about the Ruby walk
  # itself asks for that loop by name.
  def self.using(engine)
    raise ArgumentError, "an engine is one of #{ENGINES.inspect}" unless ENGINES.include?(engine)

    previous = Thread.current[:turn_engine]
    Thread.current[:turn_engine] = engine
    yield
  ensure
    Thread.current[:turn_engine] = previous
  end

  # The extension's module, or nil when it is not built or does not load --
  # asked once per process, and the reason kept.
  def self.extension
    return @extension if defined?(@extension)

    @extension = begin
      require EXTENSION
      ::RenderedStep
    rescue LoadError, StandardError => e
      @load_error = "#{e.class}: #{e.message}"
      nil
    end
  end

  def self.load_error = extension ? nil : @load_error

  # WHY THIS PROCESS CANNOT HAND THE ENGINE A TURN RIGHT NOW, as the error the
  # turn fails with, or nil when it can.
  def self.unplayable
    return unbuilt if extension.nil?
    if ActiveRecord::Base.connection.transaction_open?
      return EngineError.new(:transaction_open, "a database transaction is open around the turn, and the engine " \
                                                "writes on a connection of its own")
    end

    nil
  end

  # A turn the engine could not play: said in the log, and counted in this
  # process (`.failures`) and to anybody subscribed to `failure.rust_engine`.
  def self.failed!(error)
    FAILURES.compute(error.kind) { |count| count.to_i + 1 }
    ActiveSupport::Notifications.instrument("failure.rust_engine", kind: error.kind, message: error.message)
    Rails.logger.error { "Rust engine: a turn failed (#{error.kind}): #{error.message}" }
  end

  # How many turns the engine could not play in this process, by kind.
  def self.failures = FAILURES.each_pair.to_h

  def self.database = File.expand_path(ApplicationRecord.connection_db_config.database, Rails.root)

  # One submitted line, played by the engine on its own connection. Answers
  # the engine's document, parsed; the block receives prose as it streams.
  def self.submit(playthrough, line, request_token, &block)
    document = replay_document || models
    answer = JSON.parse(extension.submit(database, playthrough.id, line, request_token, document.to_json, &block))
    replayed!(answer["replay"]) if answer.key?("replay")
    stood!(playthrough)
    answer
  ensure
    # The engine wrote on another connection: nothing this one cached is true.
    ActiveRecord::Base.connection.clear_query_cache
  end

  # LETTING THE GAME ACT, in a game the player narrates: the submission under
  # `request_token` (its line `ACT_LINE`), played by the engine, which picks
  # the protagonist's act with one die and tells it in its own words. No
  # narrator is asked. Answers the engine's document, as `.submit` does.
  #
  # A ROOM NOBODY HAS WRITTEN IS WRITTEN BY A MODEL, so the pick may walk into
  # one only when this install has a model to ask (`.model_configured?`) or a
  # replay stands in for one. Without either, the engine is handed no model at
  # all rather than the environment's, so a game on a written world plays
  # keyless -- an offline walk included, whose guard stands in front of the
  # live document.
  def self.act(playthrough, request_token, &block)
    replay = replay_document
    unwritten = replay ? replay.fetch(:unwritten, false) : model_configured?
    document = replay || (unwritten ? models : NO_MODELS)
    answer = JSON.parse(extension.act(database, playthrough.id, request_token, unwritten, document.to_json, &block))
    replayed!(answer["replay"]) if answer.key?("replay")
    stood!(playthrough)
    answer
  ensure
    ActiveRecord::Base.connection.clear_query_cache
  end

  # STARTING A GAME ON THE ENGINE (`Engine::start_in`), told in `mode`: the
  # playthrough row, this game's copies of what the party carries and of the
  # opening room, and -- in a game the player narrates -- what walking into that
  # room notices, which is the engine's first tier and runs nowhere else.
  # Answers the new playthrough's id. `Playthrough::Session.begin!` is the
  # caller, for a game the player narrates; a narrated game starts in Ruby.
  def self.start(story, mode)
    unplayable = self.unplayable
    raise unplayable if unplayable

    answer = JSON.parse(extension.start(database, story.id, mode))
    raise exception_for(answer["error"]) if answer["error"]

    answer["playthrough"]
  ensure
    ActiveRecord::Base.connection.clear_query_cache
  end

  # WHAT THE DOCTOR REPORTS ABOUT A STORY'S NOTICED RECORDS, in the engine's
  # words (`Engine::noticed_findings`): each a hash of `code`, `severity`,
  # `message`, `remedy` and `subject` (the row's `table` and `id`). The record
  # is the engine's, so its checks are; `Story::Doctor#noticed_records` is the
  # one caller. Reads only.
  def self.noticed_findings(story)
    raise unbuilt if extension.nil?

    answer = JSON.parse(reading { |file| extension.noticed_findings(file, story.id) })
    raise exception_for(answer["error"]) if answer["error"]

    answer["findings"]
  end

  # WHAT THE DOCTOR REPORTS ABOUT A STORY'S ARCS ASKING THE PLAYER TO HOLD A
  # THING NOTHING CAN PICK UP, in the engine's words (`Engine::carry_findings`),
  # in `noticed_findings`' shape. Whether a bulk can be held is the engine's
  # carrying rule, so the check is; `Story::Doctor#uncarriable_quest_targets`
  # is the one caller. Reads only.
  def self.carry_findings(story)
    raise unbuilt if extension.nil?

    answer = JSON.parse(reading { |file| extension.carry_findings(file, story.id) })
    raise exception_for(answer["error"]) if answer["error"]

    answer["findings"]
  end

  # The models document of a turn that may ask no model.
  NO_MODELS = { route: "none", key: nil, model: nil, system_one: "off", typesafe_key: nil }.freeze

  # WHAT THE PLAYER WRITES A CHOSEN TURN'S PARAGRAPH FROM, as the engine reads
  # it off the records (`Engine::facts_card`): the act, what the arrival found,
  # what the people there did, the tolls, the wounds and the closing words, as
  # one parsed hash -- or nil for a scene the game did not choose. Reads only.
  def self.facts_card(playthrough, scene)
    raise unbuilt if extension.nil?

    answer = JSON.parse(reading { |file| extension.facts_card(file, playthrough.id, scene.id) })
    raise exception_for(answer["error"]) if answer["error"]

    answer["card"]
  end

  # KEEPS THE PLAYER'S PARAGRAPH for a scene the game chose
  # (`Engine::write_paragraph_with_consent`), on the engine's own connection,
  # and answers the row's id. The engine copies onto the row the requests a
  # narrator would have been sent for the turn and their prompt digest, and
  # keeps `consent` (`Playthrough::Paragraph::CONSENTS`). A second paragraph
  # for the scene replaces the first and clears its audit. A scene the game did
  # not choose, or a game told another way, is refused in the engine's words
  # (`not_chosen`, `wrong_mode`), and a consent word it does not know as
  # `unsupported`.
  def self.write_paragraph(playthrough, scene, text, consent:)
    unplayable = self.unplayable
    raise unplayable if unplayable

    answer = JSON.parse(extension.write_paragraph(database, playthrough.id, scene.id, text, consent.to_s))
    raise exception_for(answer["error"]) if answer["error"]

    answer["paragraph"]
  ensure
    ActiveRecord::Base.connection.clear_query_cache
  end

  # "NOT YET" TO THE ENDING THE STORY OFFERS (`Engine::put_off_ending`): the
  # due row is stamped declined, so the offer is not made again, and `/end`
  # still ends the story on it. Writes nothing while no ending is offered.
  # `Playthrough::Session#put_off_ending!` is the caller.
  def self.put_off_ending(playthrough)
    unplayable = self.unplayable
    raise unplayable if unplayable

    answer = JSON.parse(extension.put_off_ending(database, playthrough.id))
    raise exception_for(answer["error"]) if answer["error"]

    answer["put_off"]
  ensure
    ActiveRecord::Base.connection.clear_query_cache
  end

  # One line played with no model at all, in one transaction, with `decision`
  # standing in for what a person answers when it is a conversation. The
  # engine sweep's typed steps; no front end plays this way.
  def self.play(playthrough, line, decision: nil)
    answer = JSON.parse(extension.play(database, playthrough.id, line, decision))
    stood!(playthrough)
    answer
  ensure
    ActiveRecord::Base.connection.clear_query_cache
  end

  # THE ROOM THE ENGINE LEFT THE PARTY IN IS A ROOM THIS GAME HAS STOOD IN.
  # The engine snapshots a room it stands the party in and knows nothing of
  # `Playthrough::Visit`, so the visit is taken here, after every line it is
  # handed -- read fresh, because the engine wrote the move on a connection of
  # its own. A line moves the party one room at most, and the room it started
  # in was taken when the party arrived there.
  def self.stood!(playthrough)
    ActiveRecord::Base.connection.clear_query_cache
    game = Playthrough.find_by(id: playthrough.id)
    Playthrough::Visit.record!(game, game&.current_location)
  end

  # WHAT A FRONT END'S PANELS SHOW BETWEEN TURNS, as the engine reads it off
  # the records (`Playthrough::Glance`): the room, who and what is here, which
  # verbs are open and at what, the slash menu and the next beat, as one parsed
  # document. Reads only. A read the engine could not answer raises its error.
  def self.glance(playthrough)
    raise unbuilt if extension.nil?

    answer = JSON.parse(reading { |file| extension.glance(file, playthrough.id) })
    raise exception_for(answer["error"]) if answer["error"]

    answer
  end

  # THE NARRATION PROMPT'S PER-TURN SCAFFOLD, rendered by the engine against
  # fixed placeholders (`Playthrough::PromptVersion::Scaffold`). The same text
  # for as long as the extension is, so it is asked once per process.
  def self.scaffold
    raise unbuilt if extension.nil?

    @scaffold ||= extension.scaffold.freeze
  end

  # THE FILE A READ IS ANSWERED FROM, which is a copy of the database as this
  # connection sees it -- uncommitted rows included, so a test's transaction
  # or a writer asking about what it has just written reads its own rows --
  # taken page by page through SQLite's `sqlite_dbpage` and deleted once the
  # engine has read it.
  #
  # NEVER THE DATABASE ITSELF, IN THIS PROCESS. The extension carries its own
  # copy of SQLite beside the `sqlite3` gem's, and two copies in one process
  # do not see each other's locks: the engine's connection closing on the live
  # file would drop the locks this process's own connections hold on it, in
  # the middle of whatever another thread is writing. A turn is played on the
  # file because it has to write there, and the engine takes care not to
  # checkpoint when it closes; a read has no such reason, so it reads a file
  # nobody else has open.
  def self.reading
    connection = ActiveRecord::Base.connection
    Dir.mktmpdir("engine-read", Rails.root.join("tmp")) do |directory|
      file = File.join(directory, "read.sqlite3")
      pages = connection.uncached { connection.select_values("SELECT data FROM sqlite_dbpage('main') ORDER BY pgno") }
      File.binwrite(file, pages.join)
      yield file
    end
  end

  def self.unbuilt
    EngineError.new(:not_built, "the Rust engine's extension is not built or did not load " \
                                "(#{load_error}); run bin/rails engine:build")
  end
  private_class_method :reading, :unbuilt

  # WHERE THE ENGINE'S MODEL CALLS GO, read off the environment exactly as the
  # Ruby app reads it: the player's OpenRouter key as the Direct route
  # (`BaseAgent`), `OPENROUTER_MODEL` asked first, and System One on TypeSafe
  # when its key is set and on OpenRouter's decisions route otherwise
  # (`SystemOneAgent.transport`). The classifier reads through the local
  # reader at its address, named by its weights' digest
  # (`PointerClassifierAgent`), and through nothing else: either blank, the
  # engine refuses free-typed lines rather than asking Mistral. Holds the
  # keys: never log it.
  def self.models
    live_models_guard&.call
    key = ENV[SystemOneAgent::OPENROUTER_API_KEY_VARIABLE].presence
    typesafe = ENV[SystemOneAgent::TYPESAFE_API_KEY_VARIABLE].presence
    {
      route: key ? "direct" : "none", key: key, model: ENV["OPENROUTER_MODEL"].presence,
      system_one: if typesafe then "typesafe" elsif key then "decisions" else "off" end,
      typesafe_key: typesafe,
      classifier_endpoint: PointerClassifierAgent.endpoint, classifier_model: PointerClassifierAgent.model
    }.tap { |models| warn_reader_down(models) }
  end

  # Said once a process, loudly, because every free-typed line is about to be
  # refused; the engine says so again on each one.
  def self.warn_reader_down(models)
    return if models[:classifier_endpoint] && models[:classifier_model]
    return if @reader_down_warned

    @reader_down_warned = true
    Rails.logger.warn "[classifier] the local reader is not set up (#{PointerClassifierAgent::ENDPOINT_VARIABLE} " \
                      "#{models[:classifier_endpoint] ? "is set" : "is unset"}, weights " \
                      "#{models[:classifier_model] ? "found" : "missing at #{PointerClassifierAgent.weights}"}): " \
                      "every free-typed line is refused. bin/update says how to set it up."
  end
  private_class_method :warn_reader_down

  # Whether `.models` names a model for a turn to ask. Without one, a line
  # that needs a model cannot be played however often it is resubmitted.
  def self.model_configured? = ENV[SystemOneAgent::OPENROUTER_API_KEY_VARIABLE].present?

  # Called before a live models document is built; the engine sweep sets it to
  # fail the walk, as it fails one that reaches `BaseAgent.new`.
  mattr_accessor :live_models_guard

  # THE SWEEP'S PROVIDERS, for a browser step that plays on Rust: each call is
  # answered with the next of `replies` (the step's own), and `stop_after`
  # stops the turn after that journal step. `unwritten` lets a game the player
  # narrates walk into an unwritten room, written by those replies (`.act`).
  # `local_reader` reads the classifier through the local reader where no
  # `local_classifier` reply says so, for a line it leaves unread.
  # The engine's answer to what was asked is read back with `.replayed` once
  # the block has run.
  def self.replaying(replies, stop_after: nil, unwritten: false, local_reader: false)
    previous = Thread.current[:rust_engine_replay]
    Thread.current[:rust_engine_replay] = { replay: replies, stop_after: stop_after, unwritten: unwritten || nil,
                                            local_reader: local_reader || nil }.compact
    Thread.current[:rust_engine_replayed] = nil
    yield
  ensure
    Thread.current[:rust_engine_replay] = previous
  end

  # The calls the engine made of a replay, and why it did not finish cleanly
  # (`unfinished`, nil when every declared reply was asked for in order and
  # every prompt said what it had to) -- or nil when no turn played on Rust.
  def self.replayed = Thread.current[:rust_engine_replayed]

  def self.replay_document = Thread.current[:rust_engine_replay]
  def self.replayed!(value) = Thread.current[:rust_engine_replayed] = value
  private_class_method :replay_document, :replayed!

  # THE EXCEPTION an engine turn ended in. A model failure is the Ruby app's
  # own exception for it, so `Playthrough::Session.ending_for` tells the player
  # exactly what it has always told them; anything else the engine answers is
  # an `EngineError` in its words. The engine's message never carries a
  # request or a key.
  def self.exception_for(error)
    message = error.fetch("message")
    case [ error.fetch("kind"), error["failure"] ]
    in [ "interrupted", _ ] then Playthrough::Command::InterruptedError.new(message)
    in [ "previously_failed", _ ] then Playthrough::Command::PreviouslyFailedError.new(message)
    in [ "stopped", _ ] then Stopped.new(message)
    in [ "model", "crisis" ] then BaseAgent::CrisisResponseError.new(message)
    in [ "model", "no_model" ] then BaseAgent::NoModelConfiguredError.new(message)
    in [ "model", "unauthorized" ] then BaseAgent::UnauthorizedProviderError.new(message)
    in [ "model", "refused" ] then BaseAgent::RefusalError.new(message)
    in [ "model", "schema_ignored" ] then BaseAgent::SchemaIgnoredError.new(message)
    in [ "model", "unavailable" ] then ProviderUnavailable.new(message)
    in [ "model", "unexpected" ] then ReplayMismatch.new(message)
    in [ "model", _ ] then ModelFailed.new(message)
    in [ kind, _ ] then EngineError.new(kind, message)
    end
  end
end
