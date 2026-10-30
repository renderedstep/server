require "test_helper"

# A FLOOR ONE GAME HAS REACHED, and the level it raised that game's player to.
# The engine writes the rows (`lib/engine_sweep/scripts/a-floor-raises-a-level-once.yml`
# walks it); these are the statements every reader here makes about them: the
# level is the game's and never the world's, every maximum on a game is read at
# it, and the notice is the engine's own words.
class Playthrough::FloorReachedTest < ActiveSupport::TestCase
  ARRIVED = Time.zone.parse("2026-10-31T08:10:00Z")

  setup do
    @story = create(:story, start_time: Time.zone.parse("2026-10-31T08:00:00Z"))
    @landing = create(:location, story: @story, name: "The Landing")
    @first = create(:location, :stub, story: @story, name: "The First Floor", width: 12, depth: 12)
    @second = create(:location, :stub, story: @story, name: "The Second Floor", width: 12, depth: 12)
    create(:floor, location: @first, levels_up: true)
    create(:floor, location: @second, levels_up: true)
    @odile = create(:character, :protagonist, story: @story, fullname: "Odile", level: 3, hit_die: 8)
    @rowe = create(:character, story: @story, fullname: "Halkett Rowe", location: @landing, level: 2, hit_die: 10)
    @game = create(:playthrough, story: @story, character: @odile, current_location: @landing)
  end

  def reach(floor, level:, at: ARRIVED, game: @game)
    create(:playthrough_floor_reached, playthrough: game, location: floor, level: level, arrived_at: at)
  end

  test "the notice is the engine's, word for word, and a floor that raised nothing has none" do
    assert_equal "Reaching The First Floor raised Odile to level 4: 23 hit points, and healed to full.",
                 reach(@first, level: 4).to_s
    assert_nil reach(@second, level: nil).to_s
  end

  test "a level is a character's level, or none, and a game reaches a floor once" do
    reach(@first, level: 4)

    assert_predicate build(:playthrough_floor_reached, playthrough: @game, location: @second, level: Character::LEVELS.last), :valid?
    [ 0, Character::LEVELS.last + 1 ].each do |level|
      assert_not build(:playthrough_floor_reached, playthrough: @game, location: @second, level: level).valid?, "#{level} is not a level"
    end
    assert_not build(:playthrough_floor_reached, playthrough: @game, location: @first).valid?
    assert_predicate build(:playthrough_floor_reached, playthrough: create(:playthrough, story: @story), location: @first), :valid?
  end

  test "the player's level is the highest a floor raised it to, and the world's stays" do
    assert_equal [ 3, 18 ], [ @game.level_for(@odile), @game.max_hp_for(@odile) ]

    reach(@first, level: 4)
    reach(@second, level: 5, at: ARRIVED + 10.minutes)

    assert_equal [ 5, 28 ], [ @game.level_for(@odile), @game.max_hp_for(@odile) ]
    assert_equal [ 3, 18 ], [ @odile.reload.level, @odile.max_hp ]
  end

  test "the level by a story time counts only the floors reached by then" do
    reach(@first, level: 4)

    assert_equal 18, @game.max_hp_for(@odile, at: ARRIVED - 1.minute)
    assert_equal 23, @game.max_hp_for(@odile, at: ARRIVED)
  end

  test "anybody else, and another game, keep the world's level" do
    reach(@first, level: 4)
    other = create(:playthrough, story: @story, character: @odile, current_location: @landing)

    assert_equal [ 2, 16 ], [ @game.level_for(@rowe), @game.max_hp_for(@rowe) ]
    assert_equal 18, other.max_hp_for(@odile)
    assert_nil @game.max_hp_for(create(:character, :without_a_stat_block, story: @story))
  end

  test "a levelled player's condition is read, saved and mended against the game's maximum" do
    reach(@first, level: 4)
    # The game wrote her row at the world's 18 when it began; the engine heals
    # her on the arrival that raised her. A row first written now starts full.
    @game.vitals.delete_all

    row = Playthrough::Vitals.instantiate!(@game, @odile)
    assert_equal 23, row.hp_current
    assert_equal "unhurt", @game.condition.in_words

    turn = Playthrough::Turn.new(@game)
    assert_equal "hurt (20 of 23)", turn.harm!(@odile, 3).in_words
    assert_equal 23, turn.mend!(@odile, 99).hp
    assert_predicate row.reload, :valid?
    row.hp_current = 24
    assert_not row.valid?
  end

  test "a blow and a toll are said against the game's maximum when they landed" do
    reach(@first, level: 4)

    before = create(:playthrough_toll, playthrough: @game, character: @odile, hp_after: 15, story_timestamp: ARRIVED - 1.minute)
    after = create(:playthrough_toll, playthrough: @game, character: @odile, hp_after: 20, story_timestamp: ARRIVED, sequence: -2)
    blow = create(:playthrough_blow, playthrough: @game, target: @odile, hp_after: 20, story_timestamp: ARRIVED)

    assert_equal "hurt (15 of 18)", before.condition.in_words
    assert_equal "hurt (20 of 23)", after.condition.in_words
    assert_equal "hurt (20 of 23)", blow.condition.in_words
  end

  test "the read-out's sheet prints the game's level" do
    reach(@first, level: 4)

    assert_includes Playthrough::Mechanics.new(@game, model: false).state.sheet, "level 4, d8"
  end

  test "a row goes with its game and its place, and outlives its scene" do
    scene = create(:scene, story: @story, location: @landing)
    row = create(:playthrough_floor_reached, playthrough: @game, location: @first, level: 4, scene: scene)

    scene.destroy!
    assert_nil row.reload.scene_id

    @first.destroy!
    assert_not Playthrough::FloorReached.exists?(row.id)

    reach(@second, level: 5)
    @game.destroy!
    assert_empty Playthrough::FloorReached.all
  end
end
