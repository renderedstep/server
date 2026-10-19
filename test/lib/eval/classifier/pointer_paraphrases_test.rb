require "test_helper"

# THE POINTER MODEL'S PAID LINES, WITH BOTH MODELS STOOD IN FOR.
#
# What is tested is everything around the two calls: that the writer is shown
# the room and nothing else, that a corpus line is never sent to be labelled,
# that the label is the classifier's reading turned into the engine's keys,
# that no System One request is made, and that a second run spends nothing on
# what the first already bought. `FakeAgent` stands in at `BaseAgent`.
class Eval::Classifier::Pointer::ParaphrasesTest < ActiveSupport::TestCase
  STATE = {
    "location" => "Hale's Granary",
    "ways_out" => { "way_1" => { "kind" => "way out", "name" => "The Yard", "valid_intents" => [ "move" ] } },
    "other_characters" => { "person_1" => { "kind" => "person present here", "name" => "Ida Crane",
                                            "aliases" => [ "the miller" ], "valid_intents" => %w[talk attack] } },
    "available_items" => { "available_item_1" => { "kind" => "item lying here", "name" => "tin kettle",
                                                   "valid_intents" => %w[take examine] } },
    "player_items" => { "player_item_1" => { "kind" => "item the player is carrying", "name" => "brass key",
                                             "valid_intents" => %w[drop examine] } },
    "physical_actions" => { "attempt_1" => { "kind" => "one complete physical action attempt",
                                             "name" => "Offer brass key to Ida Crane; they may refuse",
                                             "valid_intents" => [ "use" ] } },
    "player_action" => ""
  }.freeze

  def label(intent, user: nil) = Eval::Classifier::Pointer::Paraphrases.label_for(STATE, "a line", intent, user: user)

  test "a reading becomes the keys of the records it named, on the intent's own list" do
    row = label({ "action" => "take", "target" => "tin kettle", "also_named" => "brass key" }).row

    assert_equal "a line", row.dig("state", "player_action")
    assert_equal({ "intent" => "take", "target" => [ "available_item_1" ], "also" => [ "player_item_1" ],
                   "named_more_than_one" => nil, "target_present" => nil }, row["label"])
    assert_equal [ "person_1" ], label({ "action" => "talk", "target" => "the miller" }).row.dig("label", "target"),
                 "a person is named by an alias as readily as by name"
    assert_nil label({ "action" => "other", "target" => "nothing" }).row.dig("label", "target")
  end

  test "a reading the cascade asks no question for, or a target off its list, is not a row" do
    assert_equal "intent throw is not one the cascade asks", label({ "action" => "throw", "target" => "brass key" }).skipped
    assert_equal "target is not on the intent's own list", label({ "action" => "take", "target" => "brass key" }).skipped
  end

  test "a second name that is the target again is no second name" do
    row = label({ "action" => "drop", "target" => "brass key", "also_named" => "brass key" }).row

    assert_equal [ "nothing" ], row.dig("label", "also")
  end

  test "an attempt is found by the token the classifier's prompt listed it under" do
    user = "## Physical Actions (token: one attempt)\nuse:offer:3:9: Offer brass key to Ida Crane; they may refuse\n"

    assert_equal [ "attempt_1" ], label({ "action" => "use", "target" => "use:offer:3:9" }, user: user).row.dig("label", "target")
  end

  test "the writer is shown the room as a player sees it, and asked for lines only" do
    prompt = Eval::Classifier::Pointer::Paraphrases.prompt(STATE, count: 7)

    assert_includes prompt, "- Ida Crane (also called the miller)"
    assert_includes prompt, "- Offer brass key to Ida Crane; they may refuse"
    assert_includes prompt, "Write 7 lines"
    assert_not_includes prompt, "available_item_1", "the writer is never shown the engine's keys"
    assert_equal [ "lines" ], Eval::Classifier::Pointer::Paraphrases::Schema.new.to_json_schema.dig(:schema, :properties).keys.map(&:to_s)
  end

  test "a second purchase writes with its own instructions, for rooms the first did not write for" do
    Dir.mktmpdir do |directory|
      rooms = Eval::Classifier::Pointer::Rooms.new(directory: File.join(directory, "rooms"), seed: 3, count: 3, io: nil).write!
      first = Eval::Classifier::Pointer::Paraphrases.new(directory: directory, rooms: rooms, io: nil).chosen(1, seed: 1).sole
      writer = FakeAgent.new({ "lines" => [ "head out" ] }, { "lines" => [ "wait" ] })
      paraphrases = Eval::Classifier::Pointer::Paraphrases.new(directory: File.join(directory, "out"), rooms: rooms,
                                                               shape: "play", exclude: [ first["room"] ],
                                                               io: nil, threads: 1)

      BaseAgent.stub(:new, ->(**_options) { writer }) { paraphrases.write!(count: 2, seed: 1) }

      assert_equal Eval::Classifier::Pointer::Paraphrases::WRITER_PLAY, writer.instructions
      written = File.readlines(paraphrases.written_path).map { |row| JSON.parse(row)["room"] }
      assert_equal 2, written.size
      assert_not_includes written, first["room"], "an excluded room is not written for again"
    end
    assert_raises(ArgumentError) { Eval::Classifier::Pointer::Paraphrases.new(directory: "x", rooms: "y", shape: "prose") }
  end

  test "lines are written, the corpus line among them is dropped, and the rest are read in their own room" do
    Dir.mktmpdir do |directory|
      rooms = Eval::Classifier::Pointer::Rooms.new(directory: File.join(directory, "rooms"), seed: 3, count: 1, io: nil).write!
      room = JSON.parse(File.readlines(rooms).first)
      thing = room.dig("state", "ways_out").values.first.fetch("name")
      corpus_line = Eval::Classifier.corpus.lines.first.typed
      writer = FakeAgent.new({ "lines" => [ "head for #{thing}", corpus_line, "sit and wait a while" ] })
      readings = [ { "intent" => "move", "target" => thing, "also_named" => "nothing" },
                   { "intent" => "other", "target" => "nothing", "also_named" => "nothing" } ]
      agents = [ writer, *readings.map { |reading| FakeAgent.new(reading) } ]
      paraphrases = Eval::Classifier::Pointer::Paraphrases.new(directory: File.join(directory, "out"), rooms: rooms,
                                                               io: nil, threads: 1)

      tally = BaseAgent.stub(:new, ->(**_options) { agents.shift or raise "one call too many" }) do
        SystemOneAgent.stub(:new, ->(**_options) { raise "a System One request was made" }) do
          paraphrases.write!(count: 1, seed: 1)
          paraphrases.label!
        end
      end

      assert_includes writer.prompts.sole, thing
      assert_equal({ "the same line is in the classifier corpus" => 1, "kept" => 2 }, tally)
      rows = File.readlines(paraphrases.labels_path).map { |row| JSON.parse(row) }
      assert_equal [ "move", "other" ], rows.map { |row| row.dig("label", "intent") }
      assert_equal [ "way_1" ], rows.first.dig("label", "target")
      assert_empty agents

      again = BaseAgent.stub(:new, ->(**_options) { raise "a second run asked again" }) do
        paraphrases.write!(count: 1, seed: 1)
        paraphrases.label!
      end
      assert_equal({ "the same line is in the classifier corpus" => 1 }, again, "nothing is bought twice")
    end
  end
end
