require "test_helper"

class FloorTest < ActiveSupport::TestCase
  test "the factory builds a valid floor" do
    assert_predicate build(:floor), :valid?
  end

  test "a floor is a whole number of rooms from 1 to MOST_ROOMS" do
    assert_predicate build(:floor, rooms: 1), :valid?
    assert_predicate build(:floor, rooms: Floor::MOST_ROOMS), :valid?
    [ 0, Floor::MOST_ROOMS + 1, 2.5, nil ].each do |rooms|
      assert_not build(:floor, rooms: rooms).valid?, "#{rooms.inspect} rooms is not a floor"
    end
  end

  test "a floor with a way down has at least two rooms, since the way down is never the entry" do
    below = create(:floor)
    floor = build(:floor, location: create(:location, :stub, story: below.location.story), down_location: below.location, rooms: 1)

    assert_not floor.valid?
    floor.rooms = 2
    assert_predicate floor, :valid?
  end

  test "its danger and hazard are words of the place call's own tables" do
    assert_predicate build(:floor, danger: "uneasy", hazard: "flooded"), :valid?
    assert_predicate build(:floor, hazard: "none"), :valid?
    assert_not build(:floor, danger: "deadly").valid?, "deadly is a seed file's room word, not a building's"
    assert_not build(:floor, hazard: "lava").valid?
  end

  test "its way down is another floor of the same story" do
    floor = create(:floor)
    story = floor.location.story

    floor.down_location = floor.location
    assert_includes floor.tap(&:validate).errors[:down_location], "is this floor itself"

    floor.down_location = create(:location, :stub, story: story)
    assert_includes floor.tap(&:validate).errors[:down_location], "is not a floor"

    floor.down_location = create(:floor).location
    assert_includes floor.tap(&:validate).errors[:down_location], "is in another story"

    floor.down_location = create(:floor, location: create(:location, :stub, story: story)).location
    assert_predicate floor, :valid?
  end

  # The engine's `floor::room_count`, `floor::grid` and `floor::footprint`.
  test "the count, the grid and the footprint are the engine's" do
    assert_equal 1, Floor.room_count(0)
    assert_equal 2, Floor.room_count(1, down: true)
    assert_equal Floor::MOST_ROOMS, Floor.room_count(5000)

    assert_equal [ 1, 1 ], Floor.grid(1)
    assert_equal [ 2, 1 ], Floor.grid(2)
    assert_equal [ 2, 2 ], Floor.grid(4)
    assert_equal [ 3, 2 ], Floor.grid(5)
    assert_equal [ 3, 3 ], Floor.grid(9)
    assert_equal [ 4, 3 ], Floor.grid(10)
    assert_equal [ 32, 32 ], Floor.grid(1000)

    assert_equal [ 12, 12 ], Floor.footprint(4)
    assert_equal [ 12, 6 ], Floor.footprint(2)
  end

  test "a place may carry a building's word only when it is a floor" do
    place = create(:location, :stub, width: 12, depth: 12)
    place.kind = "warren"
    assert_not place.valid?

    create(:floor, location: place)
    assert_predicate place.reload.tap { |floor| floor.kind = "warren" }, :valid?
  end

  test "its monster level is a character's level, or none" do
    assert_predicate build(:floor, :deep), :valid?
    assert_predicate build(:floor, monster_level: nil), :valid?
    assert_predicate build(:floor, monster_level: Character::LEVELS.last), :valid?
    [ 0, Character::LEVELS.last + 1 ].each do |level|
      assert_not build(:floor, monster_level: level).valid?, "#{level.inspect} is not a level"
    end
  end

  test "whether it raises a level is true or false, and false unless a world says so" do
    assert_equal false, create(:floor).levels_up
    assert_predicate build(:floor, levels_up: true), :valid?
    assert_not build(:floor, levels_up: nil).valid?
  end

  test "a floor falls a positive whole number of minutes after a game reaches it, or never" do
    assert_nil create(:floor).minutes
    assert_predicate build(:floor, minutes: 30), :valid?
    [ 0, -5, 2.5 ].each do |minutes|
      assert_not build(:floor, minutes: minutes).valid?, "#{minutes.inspect} is no countdown"
    end
  end

  test "a floor is stocked with whole numbers of safe rooms and healing things, and a named thing" do
    floor = create(:floor)
    assert_equal [ 0, 0, nil, nil ], [ floor.safe_rooms, floor.healing_count, floor.healing_name, floor.healing_description ]
    assert_predicate build(:floor, safe_rooms: 2, healing_count: 3, healing_name: "red draught",
                                   healing_description: "A vial of red liquid."), :valid?
    [ -1, 1.5, nil ].each do |count|
      assert_not build(:floor, safe_rooms: count).valid?, "#{count.inspect} safe rooms"
      assert_not build(:floor, healing_count: count, healing_name: "draught", healing_description: "A vial.").valid?,
                 "#{count.inspect} healing things"
    end
    assert_not build(:floor, healing_count: 1, healing_description: "A vial.").valid?, "a healing thing needs a name"
    assert_not build(:floor, healing_count: 1, healing_name: "draught").valid?, "and a description"
  end

  test "a guard posted to a floor is let go with its place, and outlives it" do
    guard = create(:character, :posted)
    place = guard.posted_to

    assert_equal [ guard ], place.posted_guards.to_a
    place.destroy!

    assert_nil guard.reload.posted_to_id
  end

  test "a floor goes with its place" do
    floor = create(:floor)

    floor.location.destroy!

    assert_not Floor.exists?(floor.id)
  end
end
