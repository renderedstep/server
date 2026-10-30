require "test_helper"

# A REST ONE GAME TOOK. The engine writes the rows
# (`lib/engine_sweep/scripts/resting-in-a-safe-room.yml` walks it); these are
# the statements every reader here makes about them: the notice is the
# engine's own words, its maximum is the game's at the rest's own time, and
# the row goes with its game and its room.
class Playthrough::RestTest < ActiveSupport::TestCase
  START = Time.zone.parse("2026-10-31T08:00:00Z")

  setup do
    @story = create(:story, start_time: START)
    @landing = create(:location, :sanctuary, story: @story, name: "The Landing")
    @first = create(:location, :stub, story: @story, name: "The First Floor", width: 12, depth: 12)
    create(:floor, location: @first, levels_up: true)
    @odile = create(:character, :protagonist, story: @story, fullname: "Odile", level: 3, hit_die: 8)
    @game = create(:playthrough, story: @story, character: @odile, current_location: @landing)
  end

  def rest(recovered:, hp_after:, at: START, game: @game)
    create(:playthrough_rest, playthrough: game, location: @landing, recovered: recovered, hp_after: hp_after,
                              story_timestamp: at)
  end

  test "the notice is the engine's, word for word" do
    assert_equal "Odile rested for an hour in The Landing and recovered 8 hit points (14 of 18).",
                 rest(recovered: 8, hp_after: 14).to_s
  end

  test "one hit point is said in the singular, and none in the plural" do
    assert_equal "Odile rested for an hour in The Landing and recovered 1 hit point (18 of 18).",
                 rest(recovered: 1, hp_after: 18).to_s
    assert_equal "Odile rested for an hour in The Landing and recovered 0 hit points (18 of 18).",
                 rest(recovered: 0, hp_after: 18).to_s
  end

  test "the maximum is the game's at the rest's own time, after a floor raised the level" do
    create(:playthrough_floor_reached, playthrough: @game, location: @first, level: 4, arrived_at: START + 10.minutes)

    assert_equal "Odile rested for an hour in The Landing and recovered 8 hit points (14 of 18).",
                 rest(recovered: 8, hp_after: 14).to_s
    assert_equal "Odile rested for an hour in The Landing and recovered 8 hit points (20 of 23).",
                 rest(recovered: 8, hp_after: 20, at: START + 20.minutes).to_s
  end

  test "a game with no player body to count hit points on has no notice" do
    @odile.update!(level: nil, hit_die: nil, strength: nil, dexterity: nil, will: nil)

    assert_nil rest(recovered: 8, hp_after: 14).to_s
  end

  test "what it mended and what was left are whole numbers from zero, and when it began is required" do
    assert_predicate build(:playthrough_rest, playthrough: @game, location: @landing, recovered: 0, hp_after: 0), :valid?
    [ { recovered: -1 }, { hp_after: -1 }, { recovered: 1.5 }, { hp_after: nil }, { story_timestamp: nil } ].each do |bad|
      assert_not build(:playthrough_rest, playthrough: @game, location: @landing, **bad).valid?, bad.inspect
    end
  end

  test "the row goes with its game and its room, and outlives its scene" do
    scene = create(:scene, story: @story, location: @landing)
    row = create(:playthrough_rest, playthrough: @game, location: @landing, scene: scene)

    assert_equal [ row ], @game.rests
    assert_equal [ row ], @landing.rests
    assert_equal [ row ], scene.rests

    scene.destroy!
    assert_nil row.reload.scene
    @game.destroy!
    assert_not Playthrough::Rest.exists?(row.id)

    shrine = create(:location, :sanctuary, story: @story, name: "The Shrine")
    create(:playthrough_rest, playthrough: create(:playthrough, story: @story, character: @odile, current_location: @landing),
                              location: shrine)
    shrine.destroy!
    assert_empty Playthrough::Rest.all
  end
end
