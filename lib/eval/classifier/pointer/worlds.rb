# ROOMS NOBODY WROTE, FOR A MODEL TO LEARN THE CLOSED SETS ON.
#
# The pointer classifier (`Eval::Classifier::Pointer`) is trained on rooms the
# engine staged, so its input is exactly what the engine sends -- the cascade
# request's `state` -- and never a Python guess at it. Those rooms come from
# here: one small world file per room, written from `vocabulary.yml` by a
# seeded `Random`, so the same seed writes the same worlds byte for byte.
#
# NEVER THE CORPUS'S SEEDED WORLDS. The classifier corpus is staged in
# `db/seeds/worlds`, and a model trained in those rooms would be measured on
# rooms it had seen. The vocabulary holds none of the proper names of a seeded
# world the corpus stands in, and `Eval::Classifier::PointerTest` checks that.
#
# WHAT A ROOM VARIES, because each is a closed set the cascade asks about:
# how many ways out (and whether one is locked or jammed, which is what makes
# an `unlock`, `pick`, `pry` or `force` attempt); how many people (and what
# else they answer to, which is the state's `aliases`); what lies on the floor
# and what the player carries (and whether any of it can be eaten, burned,
# lit or used on a door, which is what makes a `consume`, `burn` or opening
# attempt). An offer attempt is every carried thing times every person, as the
# engine lists them.
#
# A WORLD SUPPLIES PARAMETERS, NEVER BEHAVIOUR: every key written here is one
# `WorldSeed::Loader` already reads, and nothing here is loaded anywhere but a
# rolled-back bench transaction (`Eval::Classifier::Pointer::Rooms`).
class Eval::Classifier::Pointer::Worlds
  VOCABULARY = Pathname.new(__dir__).join("vocabulary.yml")

  # How many of each a room is written with, as weights: a room with nobody in
  # it and nothing on the floor is as real a closed set as a crowded one.
  PEOPLE = { 0 => 3, 1 => 4, 2 => 3, 3 => 2 }.freeze
  EXITS = { 1 => 3, 2 => 4, 3 => 3, 4 => 2 }.freeze
  LYING = { 0 => 2, 1 => 3, 2 => 3, 3 => 2, 4 => 1 }.freeze
  CARRIED = { 0 => 2, 1 => 3, 2 => 3, 3 => 2, 4 => 1 }.freeze

  def self.vocabulary = @vocabulary ||= YAML.safe_load_file(VOCABULARY)

  attr_reader :seed

  def initialize(seed:)
    @seed = seed
    @random = Random.new(seed)
  end

  # `count` world documents, each one room deep, titled so no two collide.
  def documents(count) = Array.new(count) { |index| document(index) }

  private

  def words = self.class.vocabulary

  def pick(list) = list[@random.rand(list.size)]

  def weighted(table)
    roll = @random.rand(table.values.sum)
    table.each do |value, weight|
      return value if roll < weight

      roll -= weight
    end
  end

  def chance(share) = @random.rand < share

  def document(index)
    @used = Set.new
    title = "Pointer Room #{seed}-#{index}"
    room = unique { place_name }
    exits = Array.new(weighted(EXITS)) { exit_document }
    people = Array.new(weighted(PEOPLE)) { person(room) }
    protagonist = person(nil).merge("is_protagonist" => true, "items" => carried(exits))
    lying = Array.new(weighted(LYING)) { item_document(lying_kind) }
    # A locked door's key exists somewhere in its world, or the file does not
    # load: in the hands when `#carried` put it there, otherwise on the floor.
    exits.each do |way|
      next unless way[:key] && protagonist["items"].none? { |item| item["name"] == way[:key] }

      lying << item_document(:key, name: way[:key])
    end

    {
      "format" => 2,
      "universe" => universe,
      "story" => { "title" => title, "genre" => "adventure", "start_time" => "2026-09-24T19:05:00Z",
                   "preface" => "You stand in #{room}.", "summary" => "A room staged for the pointer classifier." },
      "opening_scene" => { "location" => room, "characters" => [ protagonist, *people ].map { |p| p["fullname"] },
                           "description" => "You stand in #{room}.", "summary" => "The player stands in #{room}." },
      "characters" => [ protagonist, *people ],
      "locations" => [ { "name" => room, "detail_level" => "realized", "opening" => true,
                         "description" => "A room.", "teaser" => "A room.", "lore" => "Nothing is known.",
                         "items" => lying } ] +
                     exits.map { |way| way.fetch(:location) },
      "connections" => exits.map { |way| way.fetch(:connection).merge("between" => [ room, way.dig(:location, "name") ]) }
    }
  end

  def universe
    { "physics" => "Ordinary physics.", "technology" => "Lamps and ledgers.", "weapons" => "Knives and sticks.",
      "geographies" => "A town.", "civilizations" => "A town.", "history" => "Old.", "economics" => "Coin.",
      "politics" => "A council.", "religion" => "A quiet calendar.",
      "races" => [ { "name" => "Townsfolk", "description" => "Ordinary people of the town." } ] }
  end

  # A name nobody in this world has used yet, case-insensitively. A short list
  # (there are few names for a lockpick) can run out within one world, and
  # then the name is numbered, as a generated room numbers its own repeats.
  def unique
    name = nil
    50.times do
      name = yield
      next if @used.include?(name.downcase)

      @used << name.downcase
      return name
    end
    (2..).each do |number|
      numbered = "#{name} #{number}"
      next if @used.include?(numbered.downcase)

      @used << numbered.downcase
      return numbered
    end
  end

  def place_name
    head = pick(words["place_heads"])
    case @random.rand(7)
    when 0 then "The #{pick(words["place_adjectives"])} #{head}"
    when 1 then "#{pick(words["surnames"])}'s #{head}"
    when 2 then "#{head} #{@random.rand(1..40)}"
    when 3 then "The #{head} of #{pick(words["place_proper"])}"
    when 4 then "#{pick(words["place_proper"])} #{head}"
    when 5 then "The #{head}"
    else "#{pick(words["place_adjectives"])} #{head.downcase}"
    end
  end

  # A way out: mostly a stub nobody has written, sometimes a written room, and
  # now and then a locked or jammed door.
  def exit_document
    name = unique { place_name }
    location = { "name" => name, "detail_level" => chance(0.3) ? "realized" : "stub", "teaser" => "A way on." }
    location.merge!("description" => "A room.", "lore" => "Nothing is known.") if location["detail_level"] == "realized"
    location["population"] = "nobody"
    connection = { "distance" => pick([ "adjacent", "adjacent", "a short walk", "across the district" ]),
                   "travel_method" => pick([ "walking", "walking", "taking stairs" ]) }
    barrier = weighted({ nil => 14, "keyed" => 3, "jammed" => 2 })
    key = nil
    if barrier == "keyed"
      key = unique { "#{pick(%w[brass iron rusted small heavy silver])} #{pick(words["keys"])}" }
      connection.merge!("barrier" => "keyed", "key_template" => key)
    elsif barrier == "jammed"
      connection["barrier"] = "jammed"
    end
    { location: location, connection: connection, key: key, barrier: barrier }
  end

  def person(room)
    fullname = unique { "#{pick(words["first_names"])} #{pick(words["surnames"])}" }
    first, last = fullname.split(" ", 2)
    nickname = case @random.rand(6)
    when 0 then first
    when 1 then last
    when 2 then "the #{pick(words["roles"])}"
    when 3 then "#{pick(words["titles"])} #{last}"
    when 4 then nil
    else first
    end
    {
      "fullname" => fullname, "nickname" => nickname, "race" => "Townsfolk", "age" => @random.rand(18..70),
      "sex" => pick(%w[male female]), "is_protagonist" => false, "is_companion" => false,
      "backstory" => "A local.", "personality" => "Plain.", "appearance" => "Ordinary.", "likes" => "Quiet.",
      "dislikes" => "Noise.", "fears" => "Fire.",
      "stats" => { "level" => 3, "hit_die" => 8, "strength" => 10, "dexterity" => 10, "will" => 10 }
    }.tap { |row| row["location"] = room if room }
  end

  # What the player carries: ordinary things, and sometimes the thing a door
  # here opens to, something to eat or something to light a fire with.
  def carried(exits)
    kinds = Array.new(weighted(CARRIED)) { carried_kind }
    locked = exits.find { |way| way[:barrier] == "keyed" }
    jammed = exits.find { |way| way[:barrier] == "jammed" }
    items = kinds.map { |kind| item_document(kind) }
    items << item_document(:key, name: locked[:key]) if locked && chance(0.6)
    items << item_document(:lockpick) if locked && chance(0.3)
    items << item_document(:lever) if jammed && chance(0.5)
    items.first(5)
  end

  def carried_kind = weighted({ ordinary: 10, food: 2, drink: 1, healing: 1, firestarter: 1, combustible: 1 })

  def lying_kind = weighted({ ordinary: 12, food: 1, combustible: 1 })

  USE_KINDS = { food: "food", drink: "drink", healing: "healing", firestarter: "firestarter",
                key: "key", lockpick: "lockpick", lever: "lever" }.freeze

  def item_document(kind, name: nil)
    name ||= unique { item_name(kind) }
    @used << name.downcase
    row = { "name" => name, "description" => "A thing.", "properties" => "{}" }
    row["use_kind"] = USE_KINDS[kind] if USE_KINDS.key?(kind)
    row["combustible"] = true if kind == :combustible
    row
  end

  def item_name(kind)
    case kind
    when :food then pick(words["foods"])
    when :drink then pick(words["drinks"])
    when :healing then pick(words["healing"])
    when :firestarter then pick(words["firestarters"])
    when :combustible then pick(words["combustibles"])
    when :lockpick then pick(words["lockpicks"])
    when :lever then pick(words["levers"])
    else ordinary_name
    end
  end

  def ordinary_name
    noun = pick(words["item_nouns"])
    case @random.rand(8)
    when 0 then "#{pick(words["surnames"])}'s #{noun}"
    when 1 then "#{pick(words["place_proper"])} #{pick(words["item_specials"])}"
    when 2 then "#{noun} #{@random.rand(2..99)}"
    when 3 then "#{pick(words["item_adjectives"])} #{pick(words["item_adjectives"])} #{noun}"
    else "#{pick(words["item_adjectives"])} #{noun}"
    end
  end
end
