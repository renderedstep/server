require "test_helper"

# WHAT STANDS IN A ROOM AND WHAT LIES ABOUT IN IT, rolled from the engine's
# kit tables on the room's kind and density. What is pinned here is the roll's
# shape -- seeded on the name, one die per piece, no name twice, pieces first,
# nothing for a room with no word -- and the one writer that turns it into the
# world's own rows. The dice themselves are held to the Rust engine's by the
# `kits` vector portion (`lib/engine_vectors/kits.rb`).
class Item::KitTest < ActiveSupport::TestCase
  def roll(name = "The Reading Room", kind = "study", density = "lived-in")
    Item::Kit.roll(name: name, kind: kind, density: density)
  end

  test "every kind the game has is a kind the kits furnish" do
    assert_equal Location::Kind::KINDS.sort, Item::Kit::TABLES.fetch("kinds").keys.sort
  end

  test "a room with no kind, or one the tables lack, rolls nothing" do
    assert_empty roll("The Reading Room", nil)
    assert_empty roll("The Reading Room", "ballroom")
  end

  test "no density word means no small stuff, and the pieces are still the kind's" do
    things = roll("The Reading Room", "study", nil)

    assert things.any?
    assert things.none? { |thing| thing.kit_key.include?("/loose/") }
  end

  test "the same name rolls the same room, whatever article or spacing it is written with" do
    assert_equal roll("The Reading Room"), roll("reading   room")
    assert_not_equal roll("The Reading Room"), roll("The Map Room")
  end

  test "pieces come first, and a thing names a piece earlier in the list" do
    Item::Kit::TABLES.fetch("kinds").each_key do |kind|
      30.times do |n|
        things = roll("room #{n}", kind, "cluttered")
        pieces = things.take_while { |thing| thing.kit_key.count("/") == 1 }

        assert_equal pieces.size, things.count { |thing| thing.kit_key.count("/") == 1 }, kind
        things.select(&:within).each { |thing| assert_operator thing.within, :<, pieces.size, kind }
      end
    end
  end

  test "no room shows more than the kit's share of the cap or a name twice" do
    Item::Kit::TABLES.fetch("kinds").each_key do |kind|
      30.times do |n|
        names = roll("room #{n}", kind, "cluttered").map(&:name)

        assert_operator names.size, :<=, Item::Kit::VISIBLE, kind
        assert_equal names.uniq, names, kind
      end
    end
    assert_equal Item::Kit::MAX_VISIBLE_PER_ROOM, Item::Kit::VISIBLE + Item::Registry::MAX_PER_ROOM
  end

  test "a fixed piece is an immovable fixture, and one that can be carried off is a portable thing of its bulk" do
    things = roll.index_by(&:name)

    assert_equal [ Item::FIXTURE, "closed", Item::IMMOVABLE ], things.fetch("desk").then { [ _1.tier, _1.holds, _1.bulk ] }
    assert_equal [ Item::PORTABLE, nil, "heavy" ], things.fetch("chair").then { [ _1.tier, _1.holds, _1.bulk ] }
    assert_equal [ "on", 0 ], things.fetch("ledger").then { [ _1.how, _1.within ] }
  end

  test "a thing in a hollow piece lies in it" do
    things = roll("Cinder Lane", "street", "lived-in")
    gutter = things.index { |thing| thing.name == "gutter" }

    assert things.select { |thing| thing.within == gutter }.all? { |thing| thing.how == "in" }
    assert things.any? { |thing| thing.within == gutter }
  end

  # A PIECE'S PARTS ARE DRAWN LAST, on the same generator, so `.roll` -- what
  # the kits vector holds -- is `.furnish` less them, and a room whose pieces
  # have none rolls what it always rolled.
  test "parts are drawn last, attached to a fixed piece that came up, and the roll is the rest" do
    seen = false
    200.times do |n|
      name = "clearing #{n}"
      things = Item::Kit.furnish(name: name, kind: "forest", density: "cluttered")
      parts = things.select { |thing| thing.tier == Item::PART }

      assert_equal roll(name, "forest", "cluttered"), things - parts
      assert_operator things.size, :<=, Item::Kit::VISIBLE
      next if parts.empty?

      seen = true
      assert_equal parts, things.last(parts.size)
      parts.each do |part|
        piece = things.fetch(part.within)
        assert_equal Item::FIXTURE, piece.tier
        assert_equal [ Item::ATTACHED, "forest/#{piece.name}/attached/#{part.name}" ], [ part.how, part.kit_key ]
        assert Item::Kit::HOLD_PENALTY.key?(part.hold)
        assert_includes Item::FRAGILITIES, part.fragility
      end
    end
    assert seen, "no forest of two hundred came up with a part"
  end

  test "every hold a part names is priced, and a firmer hold costs more strength" do
    holds = Item::Kit::PARTS.values.flat_map { |parts| parts.values.map { |spec| spec.fetch("hold") } }.uniq

    assert_empty holds - Item::Kit::HOLD_PENALTY.keys
    assert_equal Item::Kit::HOLD_PENALTY.values.sort, Item::Kit::HOLD_PENALTY.values_at("loose", "firm", "stout")
  end

  # ------------------------------------------------------------------------
  # THE WRITER.

  test "an old tree is written with its parts, attached to it, holding, and lying in nobody's closed set" do
    room = create(:location, :stub, name: "Rook Wood", kind: "forest", density: "sparse")
    written = Item::Kit.new(room).furnish!
    tree = written.find { |item| item.name == "old tree" }
    parts = written.select(&:part?)

    assert_equal [ "bark", "branch", "branch" ], parts.map(&:name).sort
    assert parts.all? { |part| part.within == tree && part.how == Item::ATTACHED && part.location == room }
    assert_equal [ "firm", Item::STURDY ], parts.find { |part| part.name == "branch" }.then { [ _1.hold, _1.fragility ] }
    assert_equal [ "loose", "light", "brittle" ], parts.find { |part| part.name == "bark" }.then { [ _1.hold, _1.bulk, _1.fragility ] }
    assert_equal "The branch, attached to the old tree.", parts.first.description
    assert parts.none?(&:positioned?)
    assert_equal written.reject(&:part?).map(&:name), Item.lying_in(room).templates.unattached.order(:id).map(&:name)
  end

  test "furnishing writes the kit as the world's own rows, once" do
    room = create(:location, :stub, name: "The Reading Room", kind: "study", density: "lived-in")
    written = Item::Kit.new(room).furnish!

    assert_equal roll.map(&:name), written.map(&:name)
    assert written.all?(&:template?)
    assert written.all? { |item| item.kit_key.present? }
    desk = written.find { |item| item.name == "desk" }
    assert_equal desk, written.find { |item| item.name == "ledger" }.within
    assert_equal "The ledger, on the desk.", written.find { |item| item.name == "ledger" }.description
    assert_equal "wood", desk.material
    assert_equal "paper", written.find { |item| item.name == "ledger" }.material

    assert_empty Item::Kit.new(room.reload).furnish!
    assert_equal written.size, room.items.count
  end

  test "a name is written with the material whose names list it, and with none where no material does" do
    assert_equal "metal", Item::Kit.material_of("knife")
    assert_equal "food", Item::Kit.material_of("apple")
    assert_nil Item::Kit.material_of("empty bottle")
  end

  test "a thing the kits table says is worn is written with its place on a body, and nothing is worn" do
    room = create(:location, :stub, name: "Room 2", kind: "kitchen", density: "lived-in")
    written = Item::Kit.new(room).furnish!

    assert_equal({ "coat" => "outer", "cap" => "head" }, written.select(&:wear).to_h { |item| [ item.name, item.wear ] })
    assert written.reject { |item| Item::Kit::TABLES.fetch("wear").key?(item.name) }.none?(&:wear)
    assert written.none?(&:worn)
  end

  test "a room with no word, and a place, are never furnished" do
    assert_empty Item::Kit.new(create(:location, :stub, kind: nil)).furnish!
    place = create(:location, :stub, kind: "study", density: "lived-in", width: 10, depth: 10)
    assert_predicate place, :place?
    assert_empty Location::Generator.new(place).furnish!
  end

  test "things on a piece carry no position, and what stands on the floor of a room with a box is placed" do
    room = create(:location, :stub, :placed, name: "The Reading Room", kind: "study", density: "lived-in")
    written = Item::Kit.new(room).furnish!

    assert written.select(&:within).none?(&:positioned?)
    assert written.reject(&:within).all?(&:positioned?)
  end
end
