require "test_helper"

# WHAT A GAME THE PLAYER NARRATES HAS NOTICED, through `Playthrough::Session`
# and the records: the engine's stamp (`items.noticed_at`), the glance that
# lists only what it stamped, the look that shows the rest of what is in plain
# sight, the refusal of a line naming a thing not yet noticed, and the doctor
# that reads the record. The engine owns every rule here (its `noticed.rs` and
# tests/player_narrates.rs); this holds the server to what it reads back.
# Played on the Rust engine, on a scratch copy (`PlaysOnRust`), with no model.
#
# THE FURNISHED ROOMS' STUDY is the room: three fixtures (a closed desk, a
# windowsill and a coal scuttle), a ward stamp shut in the desk, a potted fern
# on the sill and a lump of coal in the scuttle. The stamp and the coal lie in
# something, so no tier here notices them: only a search would, and there is
# none yet.
class Playthrough::NoticedTest < ActiveSupport::TestCase
  include PlaysOnRust

  setup do
    ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence")
    @story = WorldSeed::Loader.load_file(Rails.root.join("lib/engine_sweep/worlds/the-furnished-rooms.yml"))
  end

  test "walking in notices every fixed piece and lists only what was noticed" do
    game = begin_narrating
    glance = Playthrough::Session.new(game).glance
    study = game.current_location

    assert_equal %w[coal\ scuttle desk windowsill], glance.fixtures.map(&:name).sort
    assert glance.fixtures.all?(&:noticed_at), "arriving notices every fixed piece"
    assert glance.lying_here.all?(&:noticed_at), "the panel lists only what this game noticed"
    assert_equal stamped_names(game, study) - glance.fixtures.map(&:name), glance.lying_here.map(&:name).sort
    assert_equal glance.counts.unnoticed, unnoticed_in_plain_sight(game, study).size
    assert_not_includes glance.lying_here.map(&:name), "lump of coal", "a thing in a hollow is never noticed by arriving"
  end

  test "a look shows the rest of what is in plain sight, and offers itself only while there is some" do
    game = begin_narrating
    session = Playthrough::Session.new(game)
    before = session.glance
    look = before.verb(:examine).targets.find(&:look?)

    if before.counts.unnoticed.positive?
      assert look, "examine offers a look while a look would show something"
      assert_equal game.current_location.name, look.name
      assert_equal "/look around", look.line
    else
      assert_nil look
    end

    scene = session.play("look around", request_token: "look-1")

    assert_kind_of Scene, scene
    assert_match(/\AYou look around #{Regexp.escape(game.current_location.name)}\./, scene.description)
    after = Playthrough::Session.new(game.reload).glance
    assert_equal 0, after.counts.unnoticed
    assert_nil after.verb(:examine).targets.find(&:look?), "nothing is left for a look to show"
    assert_includes after.lying_here.map(&:name), "potted fern"
    assert_operator after.lying_here.size, :>=, before.lying_here.size, "nothing noticed is forgotten"
    assert_not_includes after.lying_here.map(&:name), "lump of coal", "a look is not a search"
  end

  test "a line naming a thing not yet noticed is refused in the engine's words, and the coal stays refused after a look" do
    game = begin_narrating
    session = Playthrough::Session.new(game)

    refused = session.play("take the lump of coal", request_token: "coal-1")

    assert_kind_of Playthrough::Refusal, refused
    assert_equal :unresolved, refused.kind
    assert_match(/You have not noticed anything here by that name\. Look around the room first/, refused.text)
    assert_match(/You have noticed/, refused.offer)
    assert_not_includes refused.text, "lump of coal", "the refusal never confirms the thing exists"
    assert_predicate game.items.where(name: "lump of coal").where.not(noticed_at: nil), :none?

    session.play("look around", request_token: "look-1")
    again = Playthrough::Session.new(game.reload).play("take the lump of coal", request_token: "coal-2")

    assert_kind_of Playthrough::Refusal, again
    assert_equal :unresolved, again.kind
  end

  test "a narrated game is never stamped, offers no look, and lists the whole room" do
    game = Playthrough::Session.begin!(@story).playthrough

    glance = Playthrough::Session.new(game).glance
    assert_predicate Item.where.not(noticed_at: nil), :none?
    assert_predicate Playthrough::NpcState.where.not(noticed_at: nil), :none?
    assert_equal 0, glance.counts.unnoticed
    assert_nil glance.verb(:examine)&.targets&.find(&:look?)
    assert_includes glance.lying_here.map(&:name), "potted fern"
  end

  test "the machinery panel lists only what the game noticed, and a narrated game's lists everything" do
    game = begin_narrating
    machinery = Playthrough::Machinery.new(game, game.current_scene)

    assert machinery.lying_here.all?(&:noticed_at)
    assert_equal stamped_names(game, game.current_location), machinery.lying_here.map(&:name).sort

    narrated = Playthrough::Session.begin!(@story).playthrough
    assert_equal narrated.items_lying_in(narrated.current_location).map(&:name),
                 Playthrough::Machinery.new(narrated, narrated.current_scene).lying_here.map(&:name)
  end

  test "the doctor reads the engine's record: a playable game is healthy, an impossible stamp is found and cleared" do
    game = begin_narrating
    Playthrough::Session.new(game).play("look around", request_token: "look-1")
    assert_empty noticed_findings, "a game the engine stamped by its own rules is consistent"

    world_row = Item.templates.find_by!(name: "potted fern")
    world_row.update_columns(noticed_at: Time.current)
    narrated = Playthrough::Session.begin!(@story).playthrough
    narrated_row = narrated.items.first
    narrated_row.update_columns(noticed_at: Time.current)
    desk = game.items.find_by!(name: "desk")
    desk.update_columns(noticed_at: nil)

    findings = noticed_findings
    assert_equal({ world_row => :safe, narrated_row => :safe, desk => :manual },
                 findings.to_h { |finding| [ finding.subject, finding.remedy ] })

    results = Story::Repair.new(@story.reload).apply!
    assert results.select { |result| result.code == :noticed_record_inconsistent }.all?(&:repaired?)
    assert_nil world_row.reload.noticed_at
    assert_nil narrated_row.reload.noticed_at
    assert_equal [ desk ], noticed_findings.map(&:subject), "which moment to stamp is not on record, so a person decides"
  end

  test "a copy never carries its template's stamp" do
    template = Item.templates.find_by!(name: "potted fern")
    template.update_columns(noticed_at: Time.current)

    game = Playthrough::Session.begin!(@story).playthrough

    assert_nil game.items.find_by!(name: "potted fern").noticed_at
  end

  private

  def begin_narrating = Playthrough::Session.begin!(@story, mode: "player_narrates").playthrough

  def noticed_findings
    Story::Doctor.new(@story.reload).findings.select { |finding| finding.code == :noticed_record_inconsistent }
  end

  def stamped_names(game, room) = game.items_lying_in(room).where.not(noticed_at: nil).map(&:name).sort

  def unnoticed_in_plain_sight(game, room)
    game.items_lying_in(room).where(noticed_at: nil).reject { |item| item.within_id && item.how == "in" }
  end
end
