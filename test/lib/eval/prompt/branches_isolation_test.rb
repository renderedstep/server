require "test_helper"

# Pins for the files the branches set sits beside. Its own request identity and
# corpus digest are pinned by its kept-set test; these say the main corpus, the
# two worlds it plays and the 2026-09-05 main set are the bytes they were when
# the branches set was last judged against them. The world pins move on purpose
# when a world's file changes and the branches set's own identity does not --
# when each world gained its arc, when The Unrecorded Hour's apron became
# wearable, and when both worlds' people were dressed -- which is why it was
# not re-bought.
class Eval::Prompt::BranchesIsolationTest < ActiveSupport::TestCase
  FILES = {
    "test/fixtures/files/prompt_corpus.yml" => "152b033ddbac333f6ac13d69195a7d110b91cdc5a7048569ef5aaeba02a3d0a1",
    "db/seeds/worlds/the-salt-assizes.yml" => "8bb343b94003a744071f23f82fdf70b30f02db2d99c4d4fdc414fc6b272601c5",
    "db/seeds/worlds/the-unrecorded-hour.yml" => "8ac53706512a4fc5489b6034f6aa1a4a4f5931403b6d3ae975767eaa67deca40",
    "db/eval/prompt-2026-09-05/prompt.json" => "04e7f6bb7bd1d7f96817586977ea944b75b6043da24109cb1dfea0d71740d07e"
  }.freeze

  test "main fixtures and kept bytes are unchanged" do
    FILES.each do |path, digest|
      assert_equal digest, Digest::SHA256.file(Rails.root.join(path)).hexdigest, path
    end
  end

  test "main corpus and stored prompt identities have not moved" do
    kept = Eval::Prompt::Result.load(Eval.kept_root.join("prompt-2026-09-05"))
    assert_equal "dfd1756a8f1f91b8", Eval::Prompt.digest
    assert_equal "dfd1756a8f1f91b8", kept.corpus_digest
    assert_equal "0ffc0228b538ac73", kept.prompt_digest
  end
end
