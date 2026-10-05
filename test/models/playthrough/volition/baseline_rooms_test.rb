require "test_helper"

# THE TWELVE STAGED ROOMS THE TYPED VOLITION BASELINE IS MEASURED ON, BUILT
# OFFLINE AND PINNED BYTE FOR BYTE.
#
# `rake eval:volition_baseline` sends
# `test/fixtures/files/volition_baseline_requests.json` and nothing else, so
# this test is what makes that file the game's own request for each room: it
# stages every room from factories, asks the engine for the request
# (`Playthrough::Requests`, `volition`), and compares. Rewrite the file
# (`REWRITE=1`) only when the request or a room is meant to change; a kept set
# records the file's sha256, so a set measured on other bytes says so.
#
# THE PEOPLE ARE THE SEEDED WORLDS' OWN. Every sheet below is read out of
# `db/seeds/worlds/*.yml` by name -- the four desire sentences and both
# pursuits -- and each room is one of that world's rooms with its real exits.
# The player is the world's protagonist. What a room stages beyond the seed
# (an item, a past act, a blow, somebody following) is written here, in the
# room's own entry, so the set is reproducible from this file alone.
#
# Marek Sollen is `hostile` in his world; he is staged without it, because a
# hostile person is a foe and a foe gets no volition at all.
class Playthrough::Volition::BaselineRoomsTest < ActiveSupport::TestCase
  FIXTURE = Rails.root.join("test/fixtures/files/volition_baseline_requests.json")
  # THE SAME ROOMS WITH EVERYBODY ASKED WHAT THEY SAY AS WELL, as though the
  # speech die had let each of them speak: the request an arrival sends for
  # the people reacting to it. `rake eval:volition_baseline ROOMS=speech`
  # sends this one. Somebody with nothing to say (nobody to say it to) is
  # asked no speech question.
  SPEECH_FIXTURE = Rails.root.join("test/fixtures/files/volition_speech_baseline_requests.json")
  SHEET = %w[conscious_desire unconscious_desire recognized_need unrecognized_need desire_pursuit need_pursuit].freeze

  WORLDS = {
    lunar: {
      file: "the-lunar-cartographer.yml", player: "Isbet Marrow",
      exits: { "Grenn's Boarding House, Room 3" => [ "Mournwell Lane", "Grenn's Boarding House hallway", "Larkspur Quarter rooftops" ],
               "Grenn's Boarding House hallway" => [ "Grenn's Boarding House, Room 3", "The Bell of Saint Aravel" ],
               "The Bell of Saint Aravel" => [ "Grenn's Boarding House hallway" ] }
    },
    salt: {
      file: "the-salt-assizes.yml", player: "Coraith Vell",
      exits: { "The Causeway Court" => [ "The Tide Post", "The Vestry Hulk" ],
               "The Tide Post" => [ "The Causeway Court" ] }
    },
    ward: {
      file: "the-unrecorded-hour.yml", player: "Odile Vance",
      exits: { "Ward Office 12" => [ "The Supply Closet", "The Long Hallway" ],
               "The Supply Closet" => [ "Ward Office 12" ] }
    }
  }.freeze

  # One entry per room, in the order the run sends them. `people` are seeded
  # names in `id` order; `player_in` is where the player stands (the staged
  # room unless said); `lying` and `held` are items; `past` is acts applied
  # before the request is built, as [name, room, token shape, argument].
  ROOMS = [
    { key: "room3-grenn", world: :lunar, room: "Grenn's Boarding House, Room 3", people: [ "Grenn Ollivar" ],
      line: "measure the window frame" },
    { key: "room3-grenn-rent", world: :lunar, room: "Grenn's Boarding House, Room 3", people: [ "Grenn Ollivar" ],
      lying: [ "an envelope of rent money" ], past: [ [ "Grenn Ollivar", :wait ], [ "Grenn Ollivar", :wait ] ],
      line: "put the rent on the table" },
    { key: "hallway-grenn-alone", world: :lunar, room: "Grenn's Boarding House hallway", people: [ "Grenn Ollivar" ],
      player_in: "Grenn's Boarding House, Room 3", lying: [ "the boarding-house ledger" ],
      line: "climb out onto the rooftops" },
    { key: "bell-marek", world: :lunar, room: "The Bell of Saint Aravel", people: [ "Marek Sollen" ],
      held: { "Marek Sollen" => [ "bell-rope tally" ] }, line: "ask him what his name was" },
    { key: "bell-marek-struck", world: :lunar, room: "The Bell of Saint Aravel", people: [ "Marek Sollen" ],
      held: { "Marek Sollen" => [ "bell-rope tally" ] }, blows: [ [ "Grenn Ollivar", "Marek Sollen" ] ],
      line: "ring the bell" },
    { key: "court-ammon", world: :salt, room: "The Causeway Court", people: [ "Ammon Brace" ],
      lying: [ "Assize tide-slate" ], line: "ring the court bell" },
    { key: "court-ammon-neb", world: :salt, room: "The Causeway Court", people: [ "Ammon Brace", "Neb Halloran" ],
      line: "call the next witness" },
    { key: "tidepost-neb-alone", world: :salt, room: "The Tide Post", people: [ "Neb Halloran" ],
      player_in: "The Causeway Court", past: [ [ "Neb Halloran", :move, "The Causeway Court" ], [ "Neb Halloran", :move, "The Tide Post" ] ],
      line: "read the tide-slate" },
    { key: "tidepost-neb-deed", world: :salt, room: "The Tide Post", people: [ "Neb Halloran" ],
      held: { "Neb Halloran" => [ "the deed to his mother's roof" ] }, line: "ask who paid for the roof" },
    { key: "office-halkett", world: :ward, room: "Ward Office 12", people: [ "Halkett Rowe" ],
      lying: [ "Ward Office 12 daybook" ], line: "read the daybook" },
    { key: "office-halkett-perrin", world: :ward, room: "Ward Office 12", people: [ "Halkett Rowe", "Perrin Lasco" ],
      held: { "Perrin Lasco" => [ "a private index of amendments" ] }, lying: [ "a closure form, unsigned" ],
      line: "ask about the amendment" },
    { key: "closet-perrin-following", world: :ward, room: "The Supply Closet", people: [ "Perrin Lasco" ],
      past: [ [ "Perrin Lasco", :follow ] ], line: "go back to the office" }
  ].freeze

  def self.sheets(world)
    YAML.load_file(Rails.root.join("db/seeds/worlds", WORLDS.fetch(world)[:file]))["characters"].index_by { |sheet| sheet["fullname"] }
  end

  def stage(entry, speaking: false)
    world = WORLDS.fetch(entry[:world])
    sheets = self.class.sheets(entry[:world])
    story = create(:story)
    rooms = world[:exits].flat_map { |from, to| [ from, *to ] }.uniq.index_with { |name| create(:location, story: story, name: name) }
    world[:exits].each do |from, to|
      to.each { |name| create(:location_connection, location: rooms[from], connected_location: rooms[name]) }
    end
    room = rooms.fetch(entry[:room])
    player = create(:character, :protagonist, story: story, fullname: world[:player], nickname: world[:player].split.first)
    game = create(:playthrough, story: story, character: player, current_location: rooms.fetch(entry[:player_in] || entry[:room]))
    people = entry[:people].index_with do |name|
      create(:character, story: story, location: room, fullname: name, nickname: name.split.first, hostile: false,
                         **sheets.fetch(name).slice(*SHEET).symbolize_keys)
    end
    everybody = people.merge(entry[:blows].to_a.flatten.uniq.excluding(*people.keys).index_with do |name|
      create(:character, story: story, location: nil, deliberately_absent: true, fullname: name, nickname: name.split.first)
    end)
    Array(entry[:lying]).each { |name| create(:item, character: nil, location: room, playthrough: game, name: name, bulk: "light") }
    entry[:held].to_h.each do |name, items|
      items.each { |item| create(:item, character: people.fetch(name), location: nil, playthrough: game, name: item, bulk: "light") }
    end
    entry[:blows].to_a.each do |attacker, target|
      create(:playthrough_blow, playthrough: game, location: room, attacker: everybody.fetch(attacker), target: everybody.fetch(target))
    end
    entry[:past].to_a.each do |name, shape, where|
      who = people.fetch(name)
      past_act!(game, who, game.location_of(who) || room, shape, where && rooms.fetch(where))
    end
    ids = people.values.map(&:id)
    Playthrough::Requests.build(:volition, playthrough: game.id, characters: ids, speakers: speaking ? ids : [],
                                           location: room.id, line: entry[:line])
  end

  # AN ACT ALREADY TAKEN, AS THE ROWS IT LEFT: the record the engine writes
  # for it, decided by the die, and -- for a walk or a promise to follow --
  # where this game now has the person. Each staged person's pursuit pulls
  # toward the act they are staged taking, so it serves their conscious
  # pursuit; waiting serves nothing.
  def past_act!(game, who, from, shape, to)
    state = -> { game.npc_states.find_or_create_by!(character: who) { |row| row.location = from } }
    chosen, fact = case shape
    when :wait then [ "wait", "#{who.fullname} stayed in #{from.name} and changed nothing." ]
    when :move
      state.call.update!(location: to, following: false)
      [ "move:#{to.id}", "#{who.fullname} walked out of #{from.name} to #{to.name} and is no longer in #{from.name}." ]
    when :follow
      state.call.update!(following: true, location: game.current_location)
      [ "follow", "#{who.fullname} decided to go with #{game.character.fullname} and will travel with them." ]
    end
    waited = shape == :wait
    create(:playthrough_volition, playthrough: game, character: who, location: from, chosen: chosen, fact: fact,
                                  status: waited ? "none" : "applied", serves: waited ? "none" : "conscious",
                                  round: 1, decided_by: "die")
  end

  def requests(speaking: false)
    ROOMS.map { |entry| { "room" => entry[:key] }.merge(stage(entry, speaking: speaking)) }
  end

  test "the twelve staged requests are byte for byte the pinned ones" do
    built = "#{JSON.pretty_generate(requests)}\n"
    File.write(FIXTURE, built) if ENV["REWRITE"] == "1"

    assert_equal FIXTURE.read, built
  end

  test "the twelve staged requests with the speech question are byte for byte the pinned ones" do
    built = "#{JSON.pretty_generate(requests(speaking: true))}\n"
    File.write(SPEECH_FIXTURE, built) if ENV["REWRITE"] == "1"

    assert_equal SPEECH_FIXTURE.read, built
  end

  test "the speech rooms ask exactly the act rooms' questions, and a speech question beside them" do
    acts = JSON.parse(FIXTURE.read).index_by { |request| request["room"] }
    JSON.parse(SPEECH_FIXTURE.read).each do |request|
      asked = request["questions"].reject { |key, _| key.end_with?(":speech") }

      assert_equal acts.fetch(request["room"]), request.merge("questions" => asked), request["room"]
      request["questions"].select { |key, _| key.end_with?(":speech") }.each_value do |question|
        assert_equal "Say nothing.", question["criteria"]["speech_1"], request["room"]
      end
    end
  end

  test "every staged room offers every person more than one act" do
    JSON.parse(FIXTURE.read).each do |request|
      request["questions"].select { |key, _| key.end_with?(":act") }.each do |key, question|
        assert_operator question["criteria"].size, :>, 1, "#{request["room"]} #{key}"
      end
    end
  end

  test "the pressure question and its criteria are the same in every room" do
    pinned = JSON.parse(Rails.root.join("test/fixtures/files/volition_system_one_request.json").read)["questions"]
                 .find { |key, _| key.end_with?(":pressure") }.last
    JSON.parse(FIXTURE.read).each do |request|
      request["questions"].select { |key, _| key.end_with?(":pressure") }.each_value do |question|
        assert_equal pinned, question, request["room"]
      end
    end
  end
end
