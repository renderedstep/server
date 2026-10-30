# WHAT A FRONT END'S SIDE PANELS SHOW, for the room the player stands in.
#
# One reader, so every front end draws the same panels from the same records:
# the room and its ways out, the people here and how each of them is, what
# stands here fixed in place and what lies on or in it, what is lying here, what
# the player carries, the player's condition, the story's next
# beat, and -- through `Playthrough::Availability` -- which verbs are open, why
# the others are not, and what each can be aimed at.
#
# THE ENGINE READS IT. The Rust engine plays every turn, so it is also the one
# that says what the panels show between turns: `Playthrough::RustEngine.glance`
# hands back its document, and this holds that document as values -- ids,
# names and the engine's own sentences, never a record. So the verbs a panel
# offers are the ones the engine plays, by the engine's own check, rather than
# a second copy of its rules beside it. `Playthrough::Mechanics::State` is a
# separate reader of the same rows in Ruby, kept for the judges that compare
# the two (`EngineSweep::Dump`).
#
# IN A GAME THE PLAYER NARRATES, THE PANELS ARE WHAT IT HAS NOTICED. The engine
# keeps a record of what that game has noticed of each room (`items.noticed_at`,
# `playthrough_npc_states.noticed_at`) and lists only that here: what is lying
# here, what lies on each fixture, and every verb's targets. `examine` then
# offers one target more, a look around the room (`Availability::Target#look?`),
# for as long as a look would show something. A narrated game is never stamped
# and every list in it is whole.
#
# It reads records only: it writes nothing, calls no model and rolls no die.
# `Playthrough::Session#glance` is how a front end asks for it.
class Playthrough::Glance
  Room = Data.define(:id, :name, :within)
  Exit = Data.define(:id, :name, :written, :open)
  Person = Data.define(:id, :name, :condition, :foe, :provoked)
  # `on` is the fixture a thing lies on or in, by name, or nil. `noticed_at` is
  # the story time a game the player narrates noticed it, in the engine's
  # seconds, and nil in any other game.
  Thing = Data.define(:id, :name, :on, :noticed_at)
  # Something fixed in place: `holds` is one of `Item::HOLDS`, `state` is
  # `shut` for a closed fixture this game has not searched and `open` once it
  # has, `state` and `searched` are nil for a fixture with no inside, `on` is
  # what lies on or in
  # it, by name, and `noticed_at` is `Thing`'s.
  Fixture = Data.define(:id, :name, :holds, :state, :searched, :on, :noticed_at)
  # How much the room shows, how many closed fixtures nobody has searched, and,
  # in a game the player narrates, how many things in plain sight it has not
  # noticed yet -- what a look would show; 0 in any other game.
  Counts = Data.define(:visible, :unsearched, :unnoticed)
  # THE QUESTION ONCE EVERY GOAL IS MET, in the engine's words
  # (`glance::EndingOffer`): the heading, the arc's goals in order, the
  # question, the label of the answer that ends the story and the line it
  # plays (`/end`), and the label of "Not yet".
  EndingOffer = Data.define(:heading, :goals, :question, :end, :end_line, :not_yet)
  # THE FLOOR THE PLAYER STANDS ON AND HOW LONG IT HAS LEFT, in the engine's
  # words (`glance::Floor`): its name, the story time it gives way in this
  # game, the whole minutes until then (a part of a minute counted as one) and
  # the engine's line, "The First Floor falls in 25 minutes."
  Floor = Data.define(:name, :falls_at, :minutes_left, :countdown)

  attr_reader :playthrough, :document

  def initialize(playthrough, document = Playthrough::RustEngine.glance(playthrough))
    @playthrough = playthrough
    @document = document
  end

  def room = (Room.new(**fields(document["room"])) if document["room"])
  def exits = document["exits"].map { |exit| Exit.new(**fields(exit)) }
  def people = document["people"].map { |person| Person.new(**fields(person)) }
  def fixtures = document["fixtures"].map { |fixture| Fixture.new(**fields(fixture)) }
  def lying_here = document["lying_here"].map { |thing| Thing.new(**fields(thing)) }
  def counts = Counts.new(**fields(document["counts"]))
  def carrying = document["carrying"].map { |thing| Thing.new(**fields(thing)) }

  # The player's condition in words (`Playthrough::Vitals::Condition#in_words`),
  # nil for a player with no stat block.
  def condition = document["condition"]

  # The world's numbers for the player, one line per half of the sheet it has.
  def sheet = document["sheet"]

  # THE SENTENCE THE NARRATOR IS TOLD THE STORY IS ASKING FOR, or nil for a
  # world with no arc and for one whose arc is walked to its end.
  def next_beat = document["next_beat"]

  # Story time now, for this game.
  def story_time = document["story_time"] && Time.zone.at(document["story_time"])

  # THE COUNTDOWN, while the player stands on a floor that has one and has not
  # fallen; nil off a floor, on one with no countdown, and once it has fallen.
  # The narrator is never told it.
  def floor
    floor = document["floor"] or return nil

    Floor.new(**fields(floor), falls_at: Time.zone.at(floor["falls_at"]))
  end

  # THE ENGINE'S SENTENCE FOR A FLOOR THAT GAVE WAY UNDER THE PLAYER, for a game
  # that ended so, and nil for any other: "The First Floor gave way at 8:30 am,
  # and Odile fell with it." The death statement (`#ended`) follows it.
  def collapse = document["collapse"]

  def over? = document["over"]

  # EVERY GOAL IS MET AND THE ENDING DECIDED: `/end` ends the story on it,
  # whether or not the question is still standing. False once the game is over.
  def ending_due? = document["ending_due"]

  # THE QUESTION TO ASK, while the ending is due and the player has neither
  # taken it nor played on past it; nil otherwise. Asked once: "Not yet", or
  # any other line, withdraws it.
  def ending_offer = (EndingOffer.new(**fields(document["ending_offer"])) if document["ending_offer"])

  # HOW THE GAME IS TOLD (`Playthrough::MODES`), as the engine reads it.
  def mode = document["mode"]

  # THE TURN WAITING FOR THE PLAYER'S PARAGRAPH, in a game the player narrates:
  # the id of the scene the latest turn the game chose was answered with, until
  # a paragraph is written for it; nil otherwise. Letting the game act again is
  # not blocked by it.
  def waiting = document["waiting"]

  # WHY THE GAME STOPPED, in the words the play page and the refusal use, or nil
  # for a game still being played.
  def ended = document["ended"]

  def verbs = availability.verbs
  def verb(name) = availability.verb(name)
  def availability = @availability ||= Playthrough::Availability.new(playthrough, document)

  # What the play box completes after a slash; see `Playthrough::SlashMenu`.
  def slash_menu = @slash_menu ||= Playthrough::SlashMenu.new(playthrough, document)

  # THE SAME PANELS AS PLAIN LINES, for `rake game:mechanics`' `glance`. Names
  # only; ids and formatting beyond that are a front end's business.
  def to_s
    [
      "  room        #{room ? room.name : "nowhere"}#{" (in #{room.within})" if room&.within}",
      line("ways out", exits.map { |exit| "#{exit.name}#{" [unwritten]" unless exit.written}#{" [shut]" unless exit.open}" }, "none"),
      line("people", people.map { |person| [ person.name, person.condition, ("foe" if person.foe) ].compact.join(", ") }, "nobody else", "; "),
      line("things", things, "nothing fixed here", "; "),
      line("lying here", lying_here.map(&:name), "nothing"),
      line("carrying", carrying.map(&:name), "nothing"),
      line("condition", [ condition, *sheet ].compact, "no stat block", "; "),
      "  next beat   #{next_beat || "this world has no arc"}",
      *("  floor       #{floor.countdown}" if floor),
      *("  collapse    #{collapse}" if collapse),
      *("  ending      #{ending_offer ? ending_offer.question : "due"} (#{ending_offer&.end_line || "/end"})" if ending_due?),
      *("  ended       #{ended}" if ended),
      *verbs.map { |verb| verb_line(verb) }
    ].join("\n")
  end

  private

  def fields(object) = object.transform_keys(&:to_sym)

  # THE THINGS PANEL AS ONE LINE: each fixture, marked when it is shut and
  # unsearched, with what lies on or in it after a colon.
  def things
    fixtures.map do |fixture|
      marked = fixture.state ? "#{fixture.name} (#{[ fixture.state, ("unsearched" unless fixture.searched) ].compact.join(", ")})" : fixture.name
      fixture.on.any? ? "#{marked}: #{fixture.on.join(", ")}" : marked
    end
  end

  def line(label, values, empty, separator = ", ")
    format("  %-11s %s", label, values.presence&.join(separator) || empty)
  end

  def verb_line(verb)
    return format("  %-11s blocked -- %s", verb.name, verb.reason) unless verb.available?

    aims = verb.aims && " at #{verb.aims.map(&:name).join(", ")}"
    format("  %-11s %s%s", verb.name, verb.targets.map(&:name).join(", "), aims)
  end
end
