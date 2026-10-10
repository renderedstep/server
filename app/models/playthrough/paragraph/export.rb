# THE OWNER'S PARAGRAPHS AS A PRIVATE REFERENCE SET for the narrator, written
# to a file outside this repository.
#
# WHAT IT IS FOR, IN ORDER. First an evaluation reference set: each paragraph
# was written against the very request a narrator would have been sent for its
# turn, built and never sent (`Playthrough::Paragraph#requests`), so it is the
# reference for taste beside a single-turn case. Second, a test of the audit's
# precision: the paragraph's `audit` is what `Story::Audit`'s checks found in
# prose a person wrote against the same facts, so a flag on a paragraph the
# owner calls `good` is a false positive. Few-shot examples come only after a
# baseline, and fine-tuning only at volume; neither is here.
#
# WHAT IS IN IT: the paragraphs `Playthrough::Paragraph.eligible` holds -- the
# owner's own, in a game no invited player plays, with the request on the row
# -- and nothing else. Another player's paragraph is never written here, and
# neither is one kept with `none`.
#
# NEVER IN THE REPOSITORY. The repository is public and `db/eval/` is checked
# in, so a set made of player prose there is a publication. The path is the
# caller's and is refused anywhere inside this checkout, `db/eval/` named
# apart (`.refusal`). The file is written readable by its owner alone.
#
# IN THE PROMPT BENCH'S SINGLE-TURN CASE SHAPE (`Eval::Prompt::Corpus`): a
# `positions` list -- the world, the room the act was taken in, and the acts
# the game played before it as `setup` -- and a `cases` list, one per
# paragraph, with the line, the act, its target and the pass as `shape`. What
# the bench does not have is under each case's `reference`: the built
# requests, the prompt digest, the facts card the player wrote from, the
# paragraph, the audit, and the verdict. `Eval::Prompt::Corpus.load` reads the
# file. Its positions are a real game's, so a case is a reference beside the
# request, not a position the bench stages again.
#
# NOTHING IS ASKED OF A MODEL. Everything is read off the records, and the
# facts card is rebuilt by the engine from them (`Engine::facts_card`), as the
# player was shown it.
class Playthrough::Paragraph::Export
  class Refused < StandardError; end

  # Where the checked-in measurement lives, named in its own refusal.
  EVAL = "db/eval".freeze

  # The mode every case here was written in, so a set never mixes a typed line
  # and the engine's act without saying which.
  MODE = "player_narrates".freeze

  # Why a path may not be written, or nil. The path is resolved through any
  # link in the part of it that exists, so a link into the checkout is caught.
  def self.refusal(path)
    return "name the file to write the set to" if path.to_s.strip.empty?

    target = resolved(Pathname(path.to_s).expand_path)
    root = Rails.root.realpath
    if within?(target, root.join(EVAL))
      "#{EVAL} is checked in and published, and player prose is never kept there; name a path outside the repository"
    elsif within?(target, root)
      "#{target} is inside the repository (#{root}), which is public; name a path outside it"
    elsif target.directory?
      "#{target} is a directory; name the file to write the set to"
    end
  end

  def self.within?(path, directory) = path == directory || path.to_s.start_with?("#{directory}#{File::SEPARATOR}")

  # The path with every link in its existing part resolved.
  def self.resolved(path)
    existing = path
    rest = []
    until existing.exist? || existing.root?
      rest.unshift(existing.basename)
      existing = existing.dirname
    end
    rest.reduce(existing.realpath) { |joined, part| joined.join(part) }
  end
  private_class_method :within?, :resolved

  def initialize(path, paragraphs: Playthrough::Paragraph.eligible)
    @path = path
    @paragraphs = paragraphs
  end

  # Writes the set and answers how many cases it holds. Refuses before writing
  # anything.
  def write!
    refused = self.class.refusal(@path)
    raise Refused, refused if refused

    target = Pathname(@path.to_s).expand_path
    FileUtils.mkdir_p(target.dirname)
    body = "#{header}#{YAML.dump(document)}"
    File.open(target, File::WRONLY | File::CREAT | File::TRUNC, 0o600) { |file| file.write(body) }
    File.chmod(0o600, target)
    document["cases"].size
  end

  def document
    @document ||= begin
      entries = rows.filter_map { |paragraph| entry(paragraph) }
      { "positions" => entries.map(&:first), "cases" => entries.map(&:last) }
    end
  end

  private

  def rows = @paragraphs.includes(playthrough: :story, scene: :location).order(:id).to_a

  # One paragraph as a position and a case, or nil for one whose turn cannot
  # be found on its game's chain any more.
  def entry(paragraph)
    playthrough = paragraph.playthrough
    chain = playthrough.scene_chain
    scene = paragraph.scene
    acted = scene.engine_authored? && scene.previous_scene ? scene.previous_scene : scene
    at = chain.index(acted)
    return nil if at.nil?

    id = "paragraph-#{paragraph.id}"
    position = {
      "id" => id,
      "story" => playthrough.story.title,
      "room" => (chain[at - 1] || acted).location.name,
      "setup" => chain[0...at].filter_map(&:typed),
      "why" => "the game the owner played (playthrough #{playthrough.id}) as it stood before this turn"
    }
    kase = {
      "id" => id,
      "position" => id,
      "typed" => acted.typed,
      "act" => acted.resolved_action,
      "target" => target_of(acted),
      "shape" => paragraph.act_request&.dig("purpose"),
      "why" => "the owner's own paragraph for this turn, a reference for the request beside it",
      "reference" => reference(paragraph, playthrough, scene)
    }
    [ position, kase ]
  end

  def reference(paragraph, playthrough, scene)
    feedback = playthrough.feedbacks.find_by(scene: scene)
    {
      "mode" => MODE,
      "consent" => paragraph.consent,
      "prompt_digest" => paragraph.prompt_digest,
      "requests" => paragraph.would_ask,
      "facts_card" => Playthrough::RustEngine.facts_card(playthrough, scene),
      "paragraph" => paragraph.text,
      "written_at" => paragraph.updated_at.utc.iso8601,
      "audit" => paragraph.audit,
      "verdict" => feedback && { "verdict" => feedback.verdict, "note" => feedback.note,
                                 "by" => feedback.prose_purpose }
    }
  end

  # What the act was taken on, by the name the records give it.
  def target_of(scene)
    acted_on = scene.acted_on
    return nil if acted_on.nil?

    acted_on.respond_to?(:name) ? acted_on.name : acted_on.to_s
  end

  def header
    <<~HEADER
      # The owner's own paragraphs, each beside the request a narrator would
      # have been sent for its turn. PRIVATE: player prose, never to be checked
      # in or published. Written by rake eval:paragraphs at #{Time.current.utc.iso8601}.
    HEADER
  end
end
