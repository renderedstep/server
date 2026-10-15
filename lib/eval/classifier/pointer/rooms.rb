# THE ENGINE'S OWN STATE FOR EVERY GENERATED ROOM, WRITTEN OUT FOR TRAINING.
#
# Each world `Eval::Classifier::Pointer::Worlds` writes is staged the way a
# corpus position is (`Eval::Classifier::Stage`: its own copy, a rolled-back
# transaction, no model call) and then asked for the request a typed line
# would get there (`Playthrough::Requests.build(:cascade)`). What is kept is
# that request's `state` and, per question, the option keys it offers --
# exactly the two things the pointer model reads at bench time, built by the
# same engine code. The line itself is left empty: the trainer writes lines.
#
# One JSON object per line of `rooms.jsonl`, under a directory the caller
# names. That directory is never the repository: the rooms are training data.
class Eval::Classifier::Pointer::Rooms
  # Worlds staged per transaction. Each pass dumps every row the connection
  # sees for the engine to read, so a batch too large makes every build
  # slower; one too small pays the transaction more often.
  BATCH = 25

  LABEL = "pointer rooms".freeze

  attr_reader :directory, :seed, :count

  def initialize(directory:, seed:, count:, io: $stdout)
    @directory = Pathname.new(directory)
    @seed = seed
    @count = count
    @io = io
  end

  # Writes `worlds/*.yml` and `rooms.jsonl`; answers the path of the latter.
  def write!
    worlds = directory.join("worlds")
    FileUtils.mkdir_p(worlds)
    documents = Eval::Classifier::Pointer::Worlds.new(seed: seed).documents(count)
    documents.each do |document|
      File.write(worlds.join("#{WorldSeed.slug(document.dig("story", "title"))}.yml"), document.to_yaml)
    end

    path = directory.join("rooms.jsonl")
    File.open(path, "w") do |out|
      documents.each_slice(BATCH).with_index do |slice, index|
        stage(slice, worlds) { |row| out.puts(JSON.generate(row)) }
        @io&.puts format("  staged %d/%d", [ (index + 1) * BATCH, documents.size ].min, documents.size)
      end
    end
    path
  end

  private

  def stage(documents, worlds)
    positions = documents.map do |document|
      Eval::Classifier::Corpus::Position.new(id: WorldSeed.slug(document.dig("story", "title")),
                                             story: document.dig("story", "title"),
                                             room: document.fetch("locations").first.fetch("name"))
    end

    Eval::Classifier::Stage.open(positions, label: LABEL, roots: [ worlds ]) do |stages|
      rows = Playthrough::Requests.rows
      stages.each do |id, standing|
        built = Playthrough::Requests.build(:cascade, rows: rows, playthrough: standing.playthrough.id, line: "")
        options = built.fetch("questions").select { |_question, body| body["type"] == "choice" }
                       .transform_values { |body| body.fetch("criteria").keys }
        yield({ "room" => id, "state" => built.fetch("state"), "options" => options })
      end
    end
  end
end
