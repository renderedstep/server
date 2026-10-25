require "test_helper"

# `wear:` and `worn:` on a seed file's items: where on a body a thing is worn
# and whether it is, loaded, exported and read back, and refused where the
# engine's doctor would report the row (`Story::Doctor#worn_things`).
class WorldSeedWearTest < ActiveSupport::TestCase
  def document
    YAML.safe_load_file(Rails.root.join("lib/engine_sweep/worlds/a-dose-beyond-two-doors.yml"))
  end

  def dressed
    world = document
    world["characters"].first["items"] << { "name" => "oilskin coat", "description" => "Stiff with salt.", "wear" => "outer", "worn" => true }
    world["characters"].first["items"] << { "name" => "court black", "description" => "Plain and pressed.", "wear" => "body", "worn" => true }
    world["locations"].first["items"] << { "name" => "cap", "description" => "A wool cap.", "wear" => "head" }
    world
  end

  test "a file says where a thing is worn and whether it is, and an absent key is neither" do
    story = WorldSeed::Loader.new(dressed).load!
    items = Item.templates.where(id: Item.in_story(story)).index_by(&:name)

    assert_equal [ "outer", true ], [ items["oilskin coat"].wear, items["oilskin coat"].worn ]
    assert_equal [ "body", true ], [ items["court black"].wear, items["court black"].worn ]
    assert_equal [ "head", false ], [ items["cap"].wear, items["cap"].worn ]
    assert_equal [ nil, false ], [ items["brass key"].wear, items["brass key"].worn ]
  end

  test "export writes them, omitted when absent, and reloads to the same rows" do
    story = WorldSeed::Loader.new(dressed).load!
    exported = WorldSeed::Exporter.new(story).document
    coat = exported["characters"].first["items"].find { |item| item["name"] == "oilskin coat" }
    key = exported["locations"].flat_map { |location| Array(location["items"]) }.find { |item| item["name"] == "brass key" }

    assert_equal [ "outer", true ], coat.values_at("wear", "worn")
    assert_not key.key?("wear")
    assert_not key.key?("worn")

    exported["story"]["title"] = "A Separate Dressed World"
    copy = WorldSeed::Loader.new(exported).load!
    rows = ->(of) { Item.templates.where(id: Item.in_story(of)).order(:name).pluck(:name, :wear, :worn) }
    assert_equal rows.call(story), rows.call(copy)
  end

  test "a re-seed that no longer marks a thing takes its place and its wearing off" do
    story = WorldSeed::Loader.new(dressed).load!
    undressed = document
    undressed["characters"].first["items"] << { "name" => "oilskin coat", "description" => "Stiff with salt." }
    WorldSeed::Loader.new(undressed).load!

    coat = Item.templates.where(id: Item.in_story(story)).find_by!(name: "oilskin coat")
    assert_equal [ nil, false ], [ coat.wear, coat.worn ]
  end

  test "a place that is no place, a worn thing with none, on a floor, or two on one place, refuse the whole file" do
    [ ->(world) { world["characters"][0]["items"] << { "name" => "tail-coat", "wear" => "tail" } },
      ->(world) { world["characters"][0]["items"] << { "name" => "hand-bell", "worn" => true } },
      ->(world) { world["characters"][0]["items"] << { "name" => "cap", "wear" => "head", "worn" => "yes" } },
      ->(world) { world["locations"][0]["items"] << { "name" => "apron", "wear" => "waist", "worn" => true } },
      ->(world) { world["characters"][0]["items"] += [ { "name" => "cap", "wear" => "head", "worn" => true }, { "name" => "hat", "wear" => "head", "worn" => true } ] } ].each do |change|
      world = document
      change.call(world)
      assert_no_difference [ "Story.count", "Item.count" ] do
        assert_raises(WorldSeed::Loader::InvalidWorld) { WorldSeed::Loader.new(world).load! }
      end
    end
  end

  test "a coat over court black is two places, and the doctor finds nothing" do
    story = WorldSeed::Loader.new(dressed).load!

    assert_empty Story::Doctor.new(story).findings.select { |finding| finding.code.to_s.start_with?("wear", "worn") }
  end

  test "the doctor reports what the engine finds about worn things, in a game and in the world" do
    story = WorldSeed::Loader.new(dressed).load!
    cap = Item.templates.where(id: Item.in_story(story)).find_by!(name: "cap")
    holder = story.protagonist
    cap.update_columns(location_id: nil, character_id: holder.id, worn: true, x: nil, y: nil)
    coat = Item.templates.where(id: Item.in_story(story)).find_by!(name: "oilskin coat")
    coat.update_columns(wear: "head")

    found = Story::Doctor.new(story).findings.select { |finding| finding.code == :worn_place_taken }
    assert_equal 1, found.size
    assert_includes [ cap, coat ], found.first.subject
    assert_equal :manual, found.first.remedy
  end

  test "a story where nothing is wearable or worn does not ask the engine" do
    story = WorldSeed::Loader.new(document).load!
    Playthrough::RustEngine.stub(:wear_findings, ->(*) { flunk "asked the engine" }) do
      assert_empty Story::Doctor.new(story).findings.select { |finding| finding.code.to_s.start_with?("wear", "worn") }
    end
  end
end
