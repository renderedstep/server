require "test_helper"
require "rake"

# THE OWNER'S PARAGRAPHS AS A PRIVATE REFERENCE SET: written only outside the
# repository, holding only the owner's own paragraphs, in the prompt bench's
# case shape with the built request beside each. The games are played on the
# engine, on a scratch copy (`PlaysOnRust`), with no model anywhere.
class Playthrough::Paragraph::ExportTest < ActiveSupport::TestCase
  include PlaysOnRust

  setup do
    @outside = Pathname(Dir.mktmpdir("paragraph-export"))
    @story = WorldSeed::Loader.load_file(Rails.root.join("db/seeds/worlds/the-salt-assizes.yml"))
  end

  teardown { FileUtils.rm_rf(@outside) }

  # --- where it may write ---------------------------------------------------

  test "a path inside the repository is refused, db/eval named apart, and nothing is written" do
    inside = Rails.root.join("tmp", "paragraph-export-#{SecureRandom.hex(4)}.yml")
    {
      inside.to_s => /inside the repository/,
      inside.relative_path_from(Rails.root).to_s => /inside the repository/,
      Rails.root.join("db/eval/paragraphs.yml").to_s => %r{db/eval is checked in},
      Rails.root.join("db/eval").to_s => %r{db/eval is checked in},
      Rails.root.to_s => /inside the repository/,
      "" => /name the file/,
      @outside.to_s => /is a directory/
    }.each do |path, refusal|
      assert_match refusal, Playthrough::Paragraph::Export.refusal(path), path.inspect
      assert_raises(Playthrough::Paragraph::Export::Refused) { Playthrough::Paragraph::Export.new(path).write! }
    end
    assert_not inside.exist?
    assert_not Rails.root.join("db/eval/paragraphs.yml").exist?
  end

  test "a link out of the repository's way does not carry a path back into it" do
    link = @outside.join("into-the-repository")
    File.symlink(Rails.root.join("tmp"), link)

    assert_match(/inside the repository/, Playthrough::Paragraph::Export.refusal(link.join("set.yml").to_s))
    assert_match(/inside the repository/, Playthrough::Paragraph::Export.refusal(link.join("new/dir/set.yml").to_s))
    assert_nil Playthrough::Paragraph::Export.refusal(@outside.join("new/dir/set.yml").to_s)
  end

  # --- what it holds --------------------------------------------------------

  test "only the owner's own paragraphs are written, each beside the request it stands in for" do
    owners, scene = narrate_one_turn(player: nil, words: "You lift the slate and read the tide on it.")
    narrate_one_turn(player: create(:player), words: "An invited player's paragraph.")
    create(:playthrough_paragraph, :captured, consent: "none", playthrough: create(:playthrough, story: @story))
    path = @outside.join("set.yml")

    assert_equal 1, Playthrough::Paragraph::Export.new(path.to_s).write!

    written = path.read
    assert_no_match(/invited player's paragraph/, written)
    assert_equal 0o600, path.stat.mode & 0o777, "the set is readable by its owner alone"

    document = YAML.safe_load(written)
    kase = document["cases"].sole
    position = document["positions"].sole
    paragraph = owners.paragraphs.sole
    acted = scene.engine_authored? ? scene.previous_scene : scene

    assert_equal @story.title, position["story"]
    assert_equal kase["position"], position["id"]
    assert_equal owners.scene_chain.take_while { |turn| turn != acted }.filter_map(&:typed), position["setup"]
    assert_equal acted.typed, kase["typed"]
    assert_equal acted.resolved_action, kase["act"]
    assert_equal paragraph.act_request["purpose"], kase["shape"]

    reference = kase["reference"]
    assert_equal "player_narrates", reference["mode"]
    assert_equal "You lift the slate and read the tide on it.", reference["paragraph"]
    assert_equal paragraph.requests, reference["requests"]
    assert_equal paragraph.prompt_digest, reference["prompt_digest"]
    assert_equal Playthrough::Session.new(owners).facts_card(scene).act, reference.dig("facts_card", "act")
    assert_equal paragraph.audit, reference["audit"]
    assert_nil reference["verdict"]
  end

  test "the verdict on the paragraph goes with it, and the file reads as a prompt bench corpus" do
    owners, scene = narrate_one_turn(player: nil, words: "You lift the slate.")
    Playthrough::Feedback.record(playthrough: owners, scene: scene, verdict: "good", note: "plain")
    path = @outside.join("set.yml")
    Playthrough::Paragraph::Export.new(path.to_s).write!

    corpus = Eval::Prompt::Corpus.load(path)
    assert_equal 1, corpus.size
    assert_equal corpus.cases.sole.position, corpus.positions.sole.id
    assert_equal({ "verdict" => "good", "note" => "plain", "by" => "player" },
                 YAML.safe_load(path.read)["cases"].sole.dig("reference", "verdict"))
  end

  test "with nothing eligible the set is empty and still a corpus" do
    narrate_one_turn(player: create(:player), words: "Not the owner's.")
    path = @outside.join("empty.yml")

    assert_equal 0, Playthrough::Paragraph::Export.new(path.to_s).write!
    assert_equal 0, Eval::Prompt::Corpus.load(path).size
  end

  # --- the task -------------------------------------------------------------

  test "rake eval:paragraphs writes outside the repository and refuses inside it" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("eval:paragraphs")
    narrate_one_turn(player: nil, words: "You lift the slate.")
    path = @outside.join("task.yml")

    Rake::Task["eval:paragraphs"].reenable
    out, = capture_io { Rake::Task["eval:paragraphs"].invoke(path.to_s) }
    assert_match(/Wrote 1 paragraph to/, out)
    assert_equal 1, YAML.safe_load(path.read)["cases"].size

    Rake::Task["eval:paragraphs"].reenable
    refused = assert_raises(SystemExit) do
      capture_io { Rake::Task["eval:paragraphs"].invoke(Rails.root.join("db/eval/set.yml").to_s) }
    end
    assert_not_predicate refused, :success?
    assert_not Rails.root.join("db/eval/set.yml").exist?
  end

  private

  # One turn the game chose in a game of `player`'s, and the player's
  # paragraph for it, played with no model; answers the game and the scene.
  def narrate_one_turn(player:, words:)
    EngineSweep.without_a_model do
      game = Playthrough::Session.begin!(@story, player: player, mode: "player_narrates").playthrough
      session = Playthrough::Session.new(game)
      submission = session.act!
      scene = session.play(submission.command, request_token: submission.request_token)
      session.write_paragraph!(scene, words)
      [ game.reload, scene ]
    end
  end
end
