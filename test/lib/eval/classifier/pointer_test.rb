require "test_helper"

# THE LOCAL POINTER ARM, WITH THE MODEL STOOD IN FOR.
#
# What is tested here is everything around the model: that the rooms it trains
# on share nothing with the rooms it is measured in, that a generated world is
# one the engine stages, that an arm names it and its precision, and that a
# bench line read through it goes through the engine's own cascade and never
# reaches a chat model -- including the line the engine escalates, which a
# keyless arm must answer itself. The PyTorch model is not run: a fake stands
# in at `Eval::Classifier::Pointer`, as `FakeAgent` does at `BaseAgent`.
class Eval::Classifier::PointerTest < ActiveSupport::TestCase
  # Names whose every word is ordinary English; a shared adjective is not a
  # shared room.
  GENERIC = %w[titles place_adjectives item_adjectives].freeze

  test "the training vocabulary names nothing the corpus's seeded worlds name" do
    words = Eval::Classifier::Pointer::Worlds.vocabulary.except(*GENERIC).values.flatten.map(&:downcase)
    seeded = WorldSeed.files.flat_map do |file|
      document = YAML.safe_load_file(file)
      document["locations"].flat_map { |row| [ row["name"], *Array(row["items"]).map { |item| item["name"] } ] } +
        document["characters"].flat_map do |row|
          [ row["fullname"], row["nickname"], *Array(row["items"]).map { |item| item["name"] } ]
        end
    end.compact.map(&:downcase)

    shared = words.select { |word| seeded.any? { |name| name.match?(/\b#{Regexp.escape(word)}\b/) } }
    assert_empty shared, "a model trained on these would be measured on rooms it had seen"
  end

  test "the same seed writes the same worlds, and another seed writes others" do
    first = Eval::Classifier::Pointer::Worlds.new(seed: 7).documents(3)

    assert_equal first, Eval::Classifier::Pointer::Worlds.new(seed: 7).documents(3)
    assert_not_equal first, Eval::Classifier::Pointer::Worlds.new(seed: 8).documents(3)
  end

  test "a generated world stages, and its state is the engine's own" do
    Dir.mktmpdir do |directory|
      path = Eval::Classifier::Pointer::Rooms.new(directory: directory, seed: 3, count: 4, io: nil).write!
      rooms = File.readlines(path).map { |row| JSON.parse(row) }

      assert_equal 4, rooms.size
      rooms.each do |room|
        state = room.fetch("state")
        assert_equal %w[location ways_out other_characters available_items player_items physical_actions player_action],
                     state.keys
        assert_operator state["ways_out"].size, :>=, 1, "every generated room has a way out"
        assert_equal Eval::Classifier::Pointer.records_of(state).keys + [ "nothing" ], room.dig("options", "also_named")
      end
    end
  end

  test "a pointer arm names its model directory and its precision, and round-trips" do
    arm = Eval::Classifier::Arm.parse("pointer:/models/ettin-17m")
    quantised = Eval::Classifier::Arm.parse("pointer:/models/ettin-17m+int8")

    assert_equal [ :pointer, "/models/ettin-17m", "fp32" ], [ arm.provider, arm.model, arm.precision ]
    assert_equal "int8", quantised.precision
    assert_predicate arm, :local?
    assert_predicate arm, :pointer?
    assert_equal arm, Eval::Classifier::Arm.parse(arm.id)
    assert_equal quantised, Eval::Classifier::Arm.parse(quantised.id)
    assert_not_equal arm, quantised
    assert_raises(Eval::Classifier::Arm::UnknownProvider) do
      Eval::Classifier::Arm.new(provider: :ollama, model: "qwen3:8b", precision: "int8")
    end
  end

  test "an escalated line is read as the engine reads it with escalation off" do
    state = {
      "ways_out" => { "way_1" => { "kind" => "way out", "name" => "The Yard", "valid_intents" => [ "move" ] } },
      "other_characters" => { "person_1" => { "kind" => "person present here", "name" => "Ida Crane",
                                              "valid_intents" => %w[talk attack] } },
      "available_items" => {}, "player_items" => {},
      "physical_actions" => { "attempt_1" => { "kind" => "one complete physical action attempt",
                                               "name" => "Offer a coin to Ida Crane; they may refuse",
                                               "valid_intents" => [ "use" ] } },
      "player_action" => "tell Ida I am going to the yard"
    }
    body = lambda do |intent, present: 0.9, also: "nothing", **targets|
      answers = { "intent" => { "type" => "choice", "choice" => intent },
                  "also_named" => { "type" => "choice", "choice" => also },
                  "target_present" => { "type" => "noul", "noul" => present },
                  "named_more_than_one" => { "type" => "noul", "noul" => 0.9 } }
      targets.each { |id, key| answers[id.to_s] = { "type" => "choice", "choice" => key } }
      { "answers" => answers }
    end
    user = "## Physical Actions (token: one attempt)\nuse:offer:3:9: Offer a coin to Ida Crane; they may refuse\n"
    read = ->(answer) { Eval::Classifier::Pointer.escalated_reading(state, answer, user) }

    assert_equal({ "intent" => "talk", "target" => "Ida Crane", "also_named" => "nothing", "thrown_at" => "nothing" },
                 read.call(body.call("move", target_move: "way_1", target_talk: "person_1")),
                 "a move opened by a speaking verb is the talk it is")
    assert_equal "nothing", read.call(body.call("attack", present: 0.1, target_attack: "person_1"))["target"],
                 "below the presence gate nothing is reached for"
    assert_equal "nothing", read.call(body.call("attack", also: "way_1", target_attack: "person_1"))["also_named"],
                 "a second name off the intent's own list is not a second act"
    assert_equal "use:offer:3:9", read.call(body.call("use", target_use: "attempt_1"))["target"],
                 "an attempt is named by the token the classifier's prompt lists it under"
  end

  # Three corpus-shaped lines in the seeded office and closet: one the cascade
  # composes, one it escalates, one that reaches for nothing.
  CORPUS = <<~YML
    positions:
    - id: office
      story: The Unrecorded Hour
      room: Ward Office 12
    - id: closet
      story: The Unrecorded Hour
      room: The Supply Closet
    lines:
    - id: a-take
      position: office
      typed: take the ward stamp
      intent: take
      target: ward stamp
      shape: take
      why: composed by the cascade
    - id: a-pair
      position: closet
      typed: take the index and the apron
      intent: take
      target: Perrin's private index
      also_named: copy-room apron
      refusal: named_more_than_one
      shape: two-names-one-set
      why: named twice, so the engine escalates it
    - id: an-other
      position: office
      typed: wait
      intent: other
      shape: other
      why: no record at all
  YML

  # What the stand-in model answers, by typed line, as record NAMES.
  ANSWERS = {
    "take the ward stamp" => { intent: "take", target: "ward stamp", two: 0.05 },
    "take the index and the apron" => { intent: "take", target: "Perrin's private index", also: "copy-room apron",
                                         two: 0.93 },
    "wait" => { intent: "other", two: 0.02 }
  }.freeze

  class FakePointer
    def answer(state, questions)
      wanted = ANSWERS.fetch(state.fetch("player_action"))
      records = Eval::Classifier::Pointer.records_of(state)
      key = ->(name) { records.find { |_key, record| record["name"] == name }&.first || "nothing" }
      answers = questions.to_h do |id, question|
        if question["type"] == "noul"
          [ id, { "type" => "noul", "noul" => id == "named_more_than_one" ? wanted[:two] : 0.9 } ]
        else
          choice = case id
          when "intent" then wanted[:intent]
          when "also_named" then key.call(wanted[:also])
          when "target_#{wanted[:intent]}" then key.call(wanted[:target])
          else "nothing"
          end
          [ id, { "type" => "choice", "choice" => choice } ]
        end
      end
      { "answers" => answers }
    end

    def close; end
  end

  test "a pointer arm reads every line through the cascade and never asks a chat model" do
    corpus = Eval::Classifier::Corpus.load(written(CORPUS))
    refuse = ->(**_options) { raise "a pointer arm reached BaseAgent" }

    result = Eval::Classifier::Pointer.stub(:new, ->(**_options) { FakePointer.new }) do
      BaseAgent.stub(:new, refuse) do
        Eval::Classifier::Bench.new(corpus: corpus, arms: [ "pointer:/models/fake" ], reps: 1, io: nil).run
      end
    end

    pass = result.passes.sole
    by_id = pass.readings.index_by(&:id)
    assert_predicate result, :cascade
    assert_equal 0, pass.failures, pass.failures_by_class.inspect
    assert_in_delta 1.0, pass.accuracy
    assert_equal "typed_model", by_id["a-take"].resolved_by
    assert_equal "typed_model_escalated", by_id["a-pair"].resolved_by,
                 "the board still says which line a live turn would have sent on"
    assert_equal "pointer", by_id["a-take"].system_one_transport
    assert_not by_id["a-take"].rotated?
  end

  private

  def written(body)
    file = Tempfile.new([ "pointer_corpus", ".yml" ])
    file.write(body)
    file.close
    file.path
  end
end
