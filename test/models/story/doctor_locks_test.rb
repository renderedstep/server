require "test_helper"

# P3 WITH THE LOCKS IN: the doctor's walk from the opening room opens a keyed
# door only once its key, or any lockpick, has been reached without it. A key
# behind its own door, or two behind each other's, opens nothing, and the
# door is named (`lock_whose_key_lies_behind_it`) as well as the target it
# strands (`quest_target_unreachable`). `Story::Doctor#locks_whose_key_lies_behind_them`.
class Story::DoctorLocksTest < ActiveSupport::TestCase
  def setup
    @story = create(:story)
    @hall = create(:location, :realized, story: @story, name: "Hall")
    @vault = create(:location, :realized, story: @story, name: "Vault")
    @quest = create(:quest, story: @story, title: "The Charter")
    create(:quest_outcome, :default, quest: @quest, name: "fetched")
    step = create(:quest_step, :reach_location, quest: @quest, position: 1, target_name: "Vault")
    step.bind!(@vault, at: @story.start_time)
  end

  def findings = Story::Doctor.new(@story.reload).findings
  def codes = findings.map(&:code)

  test "a key lying behind the only door it opens strands what is behind it" do
    key = key_in(@vault, "vault key")
    lock!(@hall, @vault, key)

    assert_includes codes, :quest_target_unreachable
    lock = findings.find { |finding| finding.code == :lock_whose_key_lies_behind_it }
    assert lock, "the door is named"
    assert_equal :warning, lock.severity
    assert_match "on the far side of that same door", lock.message
    assert_not_predicate Story::Doctor.new(@story), :playable?
  end

  test "a key lying on the near side opens the door" do
    lock!(@hall, @vault, key_in(@hall, "vault key"))

    assert_not_includes codes, :quest_target_unreachable
    assert_not_includes codes, :lock_whose_key_lies_behind_it
  end

  test "a key in the protagonist's own hands opens the door from the start" do
    hero = create(:character, story: @story, is_protagonist: true, location: nil)
    key = create(:item, character: hero, name: "vault key", use_kind: "key")
    lock!(@hall, @vault, key)

    assert_not_includes codes, :lock_whose_key_lies_behind_it
  end

  test "a chain of keys is followed to its end, each behind the door before it" do
    cellar = create(:location, :realized, story: @story, name: "Cellar")
    first = key_in(@hall, "cellar key")
    second = key_in(cellar, "vault key")
    lock!(@hall, cellar, first)
    lock!(cellar, @vault, second)

    assert_not_includes codes, :quest_target_unreachable
    assert_not_includes codes, :lock_whose_key_lies_behind_it
  end

  test "two keys behind each other's doors are a cycle nobody can break into" do
    archive = create(:location, :realized, story: @story, name: "Archive")
    archive_key = key_in(@vault, "archive key")
    vault_key = key_in(archive, "vault key")
    lock!(@hall, @vault, vault_key)
    lock!(@hall, archive, archive_key)

    locks = findings.select { |finding| finding.code == :lock_whose_key_lies_behind_it }
    assert_equal 2, locks.size
    assert locks.all? { |finding| finding.message.include?("behind another lock") }
    assert_includes codes, :quest_target_unreachable
  end

  test "a lockpick in reach opens any lock, as the engine's pick choice does" do
    lock!(@hall, @vault, key_in(@vault, "vault key"))
    create(:item, :lying, location: @hall, character: nil, name: "bent wire", use_kind: "lockpick")

    assert_not_includes codes, :quest_target_unreachable
    assert_not_includes codes, :lock_whose_key_lies_behind_it
  end

  test "a jammed door can always be forced, so it strands nothing" do
    connect!(@hall, @vault, barrier: "jammed")

    assert_not_includes codes, :quest_target_unreachable
  end

  test "the sweep world built to trip it does" do
    story = WorldSeed::Loader.new(YAML.safe_load_file(EngineSweep::WORLDS.join("a-key-locked-in-with-its-door.yml"))).load!
    found = Story::Doctor.new(story).findings
    locks = found.select { |finding| finding.code == :lock_whose_key_lies_behind_it }

    assert_equal 3, locks.size
    assert_equal 1, locks.count { |finding| finding.message.include?("far side of that same door") }
    assert_equal 2, locks.count { |finding| finding.message.include?("behind another lock") }
    assert_includes found.map(&:code), :quest_target_unreachable
    assert_not_predicate Story::Doctor.new(story), :playable?
  end

  private

  def key_in(room, name)
    create(:item, :lying, location: room, character: nil, name: name, use_kind: "key")
  end

  def lock!(from, to, key) = connect!(from, to, barrier: "keyed", key_template: key)

  def connect!(from, to, **barrier)
    [ [ from, to ], [ to, from ] ].each do |one, other|
      LocationConnection.create!(location: one, connected_location: other, **barrier,
                                 distance: LocationConnection::DISTANCES.keys.first, travel_method: "walking")
    end
  end
end
