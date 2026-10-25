require "test_helper"

# WHAT A THING IS MADE OF, as the doctor reads it: `items.material` against
# what the engine's materials table settles about a thing of it
# (`Engine::material_findings`, through `Story::Doctor#material_records`). The
# engine owns the rule (its `material.rs` and `vectors/material.json`); this
# holds the server to what it reads back. On a scratch copy (`PlaysOnRust`),
# since the engine reads the records on a connection of its own. No model.
class Item::MaterialTest < ActiveSupport::TestCase
  include PlaysOnRust

  setup do
    @story = WorldSeed::Loader.load_file(Rails.root.join("lib/engine_sweep/worlds/the-furnished-rooms.yml"))
  end

  test "a story with no material on any row asks the engine nothing and finds nothing" do
    assert_empty material_findings
  end

  test "a material its other columns agree with is no finding" do
    item("lump of coal").update!(material: "stone", combustible: false)
    item("potted fern").update!(material: "pottery", fragility: "brittle")

    assert_empty material_findings
  end

  test "a material its other columns contradict is a manual warning on that row" do
    jar = item("potted fern")
    jar.update!(material: "glass", combustible: true)

    findings = material_findings
    assert_equal [ jar ], findings.map(&:subject)
    assert_equal :warning, findings.first.severity
    assert_equal :manual, findings.first.remedy
    assert_match(/combustible, and glass never is/, findings.first.message)
    assert_match(/sturdy, and glass is only ever fragile or brittle/, findings.first.message)
  end

  private

  def item(name) = Item.in_story(@story).templates.find_by!(name: name)

  def material_findings
    Story::Doctor.new(@story.reload).findings.select { |finding| finding.code == :item_material_contradicts }
  end
end
