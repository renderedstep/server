# PAID TRAINING LINES FOR THE POINTER MODEL: WRITTEN BY ONE CALL, LABELLED BY ANOTHER.
#
# Stage 1 trained the pointer model on lines built from templates and found its
# misses were the lines templates cannot write: a thing named by description,
# idiom and register, negation and intention. This is stage 2's answer, in two
# steps that both spend money and both go through `BaseAgent`:
#
#   1. WRITE. A chat model is shown one generated room (`Pointer::Rooms`) as a
#      player would see it and asked for `PER_CALL` lines a player might type
#      there (`WRITER` below). It is asked for lines and NOTHING ELSE: what it
#      meant by a line is not a label, because the writer is not the reader
#      the pointer model replaces.
#   2. LABEL. Each line is read by the classifier call exactly as a bench line
#      is (`Playthrough::Requests.read_line`, System One off, the arm pinned),
#      in the same staged room, and that reading is the label. The labeller is
#      the incumbent classifier model, which is the cascade's own escalation
#      reader; the ceiling of a model trained on its labels is that model.
#
# WHAT IS NEVER READ OR SENT. TypeSafe's terms forbid training on Jev's
# outputs, so no System One request is made here and no stored answer of any
# kind is read. The classifier corpus is the yardstick and stays unseen: it
# is not in either prompt, its rooms are not the rooms here (`Pointer::Worlds`
# shares no name with the seeded worlds, and a test holds that), and a written
# line that happens to equal a corpus line is dropped before it is labelled.
#
# WHAT IS WRITTEN, AND WHERE. Two files under a directory the caller names,
# never the repository, because both are training data: `written.jsonl` (a room
# and the lines written for it, one call per row) and `labels.jsonl` (one row
# per labelled line, in `live_lines.py`'s row shape so `train.py --paid` reads
# it as it reads the owner's lines). Both steps resume: a room already written
# is not written again and a line already labelled is not asked again, so a
# killed run spends nothing twice.
#
# THE LABEL IS A KEY, NOT A NAME. The classifier answers with names; a row is
# kept only when its target is a record on the intent's own list (or nothing),
# so the pointer model is taught to point at what the engine offered. A
# reading the cascade asks no question for (`throw`) is dropped and counted,
# as is a failed call. The two yes/no readings carry no label: the classifier
# answers neither, so a row teaches the intent and the two pointers only.
class Eval::Classifier::Pointer::Paraphrases
  LABELLER = "mistralai/mistral-medium-3.1".freeze
  PER_CALL = 25

  # The writer's temperature. High on purpose: the point is lines unlike each
  # other and unlike the templates, and nothing reads the writer's answer but
  # the labeller.
  TEMPERATURE = 0.9

  GROUPS = %w[ways_out other_characters available_items player_items physical_actions].freeze

  # Which of the room's lists each intent's target is read from: the same
  # mapping `live_lines.py` uses for the owner's lines.
  TARGET_GROUPS = {
    "move" => %w[ways_out], "talk" => %w[other_characters], "attack" => %w[other_characters],
    "take" => %w[available_items], "drop" => %w[player_items],
    "examine" => %w[available_items player_items], "use" => %w[physical_actions]
  }.freeze
  INTENTS = (TARGET_GROUPS.keys + [ "other" ]).freeze

  WRITER = <<~TEXT.freeze
    You write test lines for a parser in a text adventure game. You are shown one
    room exactly as the player sees it, and you write lines a real player might
    type there, one command or remark per line.

    Write the way real players type, not the way a manual is written. Vary them:
    - plain commands that use a thing's or a person's full name, part of it, or a
      nickname;
    - things named by DESCRIPTION instead of by name: where it is, what it looks
      like, what it is for, which one of several;
    - idiom, slang and register: casual, formal, terse, wordy, archaic, polite,
      rude; misspellings and missing words now and then;
    - negation, hesitation, intention and the impossible: what the player will
      not do, wants to do later, or cannot do;
    - lines that name two things in the room, or ask for two acts at once;
    - lines that speak to someone, ask them something or are said aloud;
    - lines that name something that is NOT in the room, or a place that is not
      a listed way out;
    - looking at, taking, dropping, giving, using, attacking, going places, and
      lines that are none of these (waiting, thinking, emotes, questions about
      the game).

    Terse commands are the easy case and need only a few lines. Most lines
    should be the harder kinds: a thing picked out by description, an idiom, a
    whole sentence a person would say, a refusal or a change of mind, two
    things in one line. Write them as people really type, from two words to
    about twenty.

    Mix them; do not write the kinds in order, and do not write the same verb
    twice in a row. Every line stands alone. Do not number them, do not explain
    them, and do not say which kind each one is.
  TEXT

  # The second purchase's writer. `WRITER`'s lines came back short (4.2 words
  # on average) and mostly `use`, with almost no attacks, while the pointer
  # model's misses on the corpus were whole sentences, attacks, names that are
  # not in the room and plain named exits. So this one asks for those, in
  # shares, and holds the listed attempts to two lines a call. The shares are
  # the writer's to keep or not: what was actually bought is the labeller's
  # tally, so count the intents in `labels.jsonl` before training on them.
  WRITER_PLAY = <<~TEXT.freeze
    You write test lines for a parser in a text adventure game. You are shown one
    room exactly as the player sees it, and you write lines a real player might
    type there in the middle of a game, one command or remark per line.

    These players type whole sentences, not two-word commands. Not "take lamp"
    but "I lift the lamp off its hook before the guard turns round"; not "go
    north" but "head up the north stairs and see who is shouting". Nearly every
    line is six to fifteen words, a few are longer, and no more than three in a
    call are under five words. Bare commands or first person, casual or wordy,
    a reason or a condition tucked into the same sentence, a misspelling or a
    missing word now and then.

    Spread the lines across these kinds, in about these shares:
    - about a quarter go somewhere: a listed way out named plainly, by its full
      name or part of it, with whatever verb fits (go, head, climb, cross,
      leave, follow, step); now and then a place that is not listed;
    - about a fifth are violence toward someone who is here: plain words and
      slang or idiom for hitting, grabbing, rushing or hurting them, not only
      the word "attack";
    - about a fifth name a person, a thing or a place that is NOT in the room:
      someone who is elsewhere or was only mentioned, a thing not lying here,
      a room not listed; talking to them, hitting them, taking it, going there;
    - the rest: talking to and asking the people here, looking at and reading
      things, taking and dropping things, and lines that are none of these:
      impossible or fanciful acts, waiting, feelings, questions about the game.

    At most two lines may try one of the "Things The Player Could Try"; giving or
    offering something to someone, eating and drinking count as those.

    Mix them; do not write the kinds in order, and do not write the same verb
    twice in a row. Every line stands alone. Do not number them, do not explain
    them, and do not say which kind each one is.
  TEXT

  # The writer instructions by name, for `SHAPE=`. `stage2` is the first
  # purchase's, kept so that purchase can be read and repeated.
  SHAPES = { "stage2" => WRITER, "play" => WRITER_PLAY }.freeze

  # Only the lines. A label would be the writer's opinion, and the writer is
  # not the reader being imitated.
  class Schema < RubyLLM::Schema
    array :lines, of: :string, description: "Lines a player might type in this room, one command or remark each."
  end

  # A row of `labels.jsonl` built from one reading, or the reason it was not.
  Label = Data.define(:row, :skipped)

  attr_reader :directory, :rooms, :worlds, :writer

  # `rooms` is `Pointer::Rooms`' output, `rooms.jsonl` beside its `worlds/`.
  # `exclude` is room ids an earlier purchase already wrote for, so a second
  # purchase buys lines for rooms the first did not.
  def initialize(directory:, rooms:, shape: "stage2", exclude: [], io: $stdout, threads: Eval::Concurrency.requested)
    @directory = Pathname.new(directory)
    @rooms = Pathname.new(rooms)
    @worlds = @rooms.dirname.join("worlds")
    @writer = SHAPES.fetch(shape) { raise ArgumentError, "No writer shape #{shape.inspect}; there are #{SHAPES.keys.join(", ")}." }
    @exclude = exclude.to_set
    @io = io
    @threads = threads
    @append = Mutex.new
  end

  def written_path = directory.join("written.jsonl")
  def labels_path = directory.join("labels.jsonl")

  # The first `count` rooms of a seeded shuffle, less the excluded ones, so a
  # larger run is a superset of a smaller one and a trial's rooms are the
  # first rooms of the full run.
  def chosen(count, seed:)
    File.readlines(rooms).map { |row| JSON.parse(row) }.shuffle(random: Random.new(seed))
        .reject { |room| @exclude.include?(room["room"]) }.first(count)
  end

  # STEP 1: lines for each chosen room not yet written, one call each.
  def write!(count:, seed:)
    FileUtils.mkdir_p(directory)
    done = read_rows(written_path).map { |row| row["room"] }.to_set
    todo = chosen(count, seed: seed).reject { |room| done.include?(room["room"]) }
    pinned do
      Eval::Concurrency.fan(todo, threads: @threads) do |room|
        lines = write_room(room)
        append(written_path, { "room" => room["room"], "lines" => lines })
        @io&.puts format("  wrote %-34s %2d lines", room["room"], lines.size)
      end
    end
    read_rows(written_path)
  end

  # STEP 2: every written line not yet labelled, read by the classifier in its
  # own staged room. Answers the tally of what was kept and why the rest were not.
  def label!(corpus: Eval::Classifier.corpus)
    held_out = corpus.lines.map { |line| self.class.normalized(line.typed) }.to_set
    asked = read_rows(labels_path).map { |row| [ row["room"], row["line"] ] }.to_set
    states = File.readlines(rooms).to_h { |row| room = JSON.parse(row); [ room["room"], room["state"] ] }
    tally = Hash.new(0)
    work = read_rows(written_path).flat_map do |row|
      row["lines"].filter_map do |line|
        if held_out.include?(self.class.normalized(line))
          tally["the same line is in the classifier corpus"] += 1
          next
        end
        next if asked.include?([ row["room"], line ])

        [ row["room"], line ]
      end
    end.uniq
    return tally if work.empty?

    pinned do
      Eval::Classifier::Stage.open(positions(work.map(&:first).uniq), label: Eval::Classifier::Pointer::Rooms::LABEL,
                                                                    roots: [ worlds ]) do |stages|
        rows = Playthrough::Requests.rows
        Eval::Concurrency.fan(work, threads: @threads) do |room, line|
          label = read(stages.fetch(room), states.fetch(room), room, line, rows)
          append(labels_path, label.row || { "room" => room, "line" => line, "skipped" => label.skipped })
          tally[label.skipped || "kept"] += 1
        end
      end
    end
    tally
  end

  # One reading turned into a training row: the room's own state with the line
  # in it, and the keys the classifier's names resolve to.
  def self.label_for(state, line, intent, user: nil)
    action = intent.fetch("action").to_s
    return Label.new(row: nil, skipped: "intent #{action} is not one the cascade asks") unless INTENTS.include?(action)

    target = nil
    if TARGET_GROUPS.key?(action)
      target = key_for(state, TARGET_GROUPS.fetch(action), intent["target"], user)
      return Label.new(row: nil, skipped: "target is not on the intent's own list") if target.nil?
    end
    also = key_for(state, GROUPS, intent["also_named"], user)
    also = "nothing" if also.nil? || (also != "nothing" && also == target)

    Label.new(skipped: nil, row: {
      "state" => state.merge("player_action" => line), "line" => line,
      "label" => { "intent" => action, "target" => target && [ target ], "also" => [ also ],
                   "named_more_than_one" => nil, "target_present" => nil }
    })
  end

  # A name the classifier answered, as the key of the record it names in
  # `groups`; "nothing" for no record, nil for a name on none of them. A
  # physical attempt is named by the token the prompt listed it under.
  def self.key_for(state, groups, name, user)
    return "nothing" if name.blank? || name == "nothing"

    groups.each do |group|
      state.fetch(group, {}).each do |key, entry|
        return key if entry["name"] == name || Array(entry["aliases"]).include?(name)
      end
    end
    return unless groups.include?("physical_actions")

    listed = user.to_s.lines.map(&:strip).find { |row| row.start_with?("#{name}: ") }&.delete_prefix("#{name}: ")
    state.fetch("physical_actions", {}).find { |_key, entry| entry["name"] == listed }&.first
  end

  def self.normalized(text) = text.to_s.downcase.gsub(/[^a-z0-9]+/, " ").strip

  # The room as a player sees it, which is all the writer is told.
  def self.prompt(state, count: PER_CALL)
    listing = lambda do |group|
      entries = state.fetch(group, {}).values
      return "- none" if entries.empty?

      entries.map do |entry|
        aliases = Array(entry["aliases"])
        "- #{entry["name"]}#{" (also called #{aliases.join(", ")})" if aliases.any?}"
      end.join("\n")
    end

    <<~PROMPT
      ## Where The Player Is
      #{state["location"]}

      ## Ways Out
      #{listing.call("ways_out")}

      ## Who Is Here
      #{listing.call("other_characters")}

      ## What Is Lying Here
      #{listing.call("available_items")}

      ## What The Player Is Carrying
      #{listing.call("player_items")}

      ## Things The Player Could Try
      #{listing.call("physical_actions")}

      Write #{count} lines a player might type here.
    PROMPT
  end

  private

  def write_room(room)
    content = BaseAgent.new(purpose: "world").with_instructions(writer).with_temperature(TEMPERATURE)
                       .with_schema(Schema).ask(self.class.prompt(room.fetch("state"))).content
    Array(content["lines"]).map { |line| line.to_s.squish }.reject(&:blank?).uniq
  rescue StandardError => error
    @io&.puts "  #{room["room"]}: #{error.class}: #{error.message}"
    []
  end

  def read(standing, state, room, line, rows)
    playthrough = Playthrough.find(standing.playthrough.id)
    answering = Eval::Classifier::Bench::Answering.new(nil, arm, playthrough, rows)
    user = nil
    read = Playthrough::Requests.read_line(playthrough, line, system_one: false, rows: rows) do |request|
      user = request["user"]
      answering.call(request)
    end
    return Label.new(row: nil, skipped: "the call failed (#{answering.failure.class})") if answering.failure

    label = self.class.label_for(state, line, read.fetch("intent"), user: user)
    return label unless label.row

    Label.new(skipped: nil, row: label.row.merge("room" => room, "source" => "paid label #{LABELLER}",
                                                 "answer" => read.fetch("intent").slice("action", "target", "also_named")))
  rescue StandardError => error
    Label.new(row: nil, skipped: "the read failed (#{error.class})")
  end

  def positions(ids)
    ids.map do |id|
      document = YAML.safe_load_file(worlds.join("#{id}.yml"))
      Eval::Classifier::Corpus::Position.new(id: id, story: document.dig("story", "title"),
                                             room: document.fetch("locations").first.fetch("name"))
    end
  end

  def arm = @arm ||= Eval::Classifier::Arm.parse(LABELLER)

  # Both steps on the labeller's model alone and with no provider retries, so
  # a failed call is a failed call and never another model's answer.
  def pinned(&block)
    Eval.without_provider_retries { arm.pinned { block.call } }
  end

  def read_rows(path) = path.exist? ? File.readlines(path).map { |row| JSON.parse(row) } : []

  def append(path, row)
    @append.synchronize { File.open(path, "a") { |file| file.puts(JSON.generate(row)) } }
  end
end
