require "test_helper"

# WHAT `rake game:mechanics` PRINTS AFTER A LINE: the read-out, which is
# `Playthrough::Mechanics#state` -- the second reader of the rows, kept so the
# two languages are held to one answer -- over what the Rust engine wrote. Each
# line is played as the console plays it (`EngineSweep::RustMechanics`): by the
# engine, with no model, on a scratch copy of the database (`PlaysOnRust`).
#
# The world is `Playthrough::MechanicsTest`'s, shaped like
# `the-unrecorded-hour.yml`.
class Playthrough::MechanicsReadOutTest < ActiveSupport::TestCase
  include PlaysOnRust

  def setup
    @story = create(:story)
    @vance = create(:character, story: @story, fullname: "Odile Vance", is_protagonist: true)

    @office = create(:location, story: @story, name: "Ward Office 12")
    @closet = create(:location, story: @story, name: "The Supply Closet")
    @hallway = create(:location, :stub, story: @story, name: "The Long Hallway")
    connect(@office, @closet)
    connect(@office, @hallway)

    # Rowe is standing in the office, and that is a record on him now rather
    # than something read back out of a scene's cast.
    @rowe = create(:character, story: @story, fullname: "Halkett Rowe", location: @office)

    # The world's opening arrival. What puts Rowe in the room is his own
    # whereabouts (`characters.location_id`, set on the factory above); the
    # scene's cast is a snapshot of that and no longer the source of it.
    @opening = create(:scene, story: @story, location: @office, characters: [ @vance, @rowe ],
                              description: "The gap in the daybook is still under your hand.")
    @playthrough = create(:playthrough, story: @story, character: @vance,
                                        current_location: @office, current_scene: @opening)

    # WHAT IS ON THE FLOOR, IN THIS GAME. `lying_here` writes the world's own
    # row and then takes this playthrough's copy of it, which is what the loop
    # resolves a `take` against -- so it has to run after the playthrough
    # exists. The closet is snapshotted here too rather than on arrival,
    # because a test that walks in wants to assert what is waiting there.
    @stamp = lying_here(@playthrough, @office, name: "ward stamp")
    @index = lying_here(@playthrough, @closet, name: "Perrin's private index")

    # WHAT THE PLAYER HAS IS THE PLAYTHROUGH'S, not the protagonist's: this is
    # `items.playthrough_id`, the closed set `drop` resolves against. Created
    # after the playthrough on purpose -- an item held by the protagonist would
    # be the story's STARTING INVENTORY, which a new playthrough copies rather
    # than carries, and the copy is not the row a test can then follow.
    @daybook = create(:item, :carried, playthrough: @playthrough, name: "Ward Office 12 daybook")
  end

  def connect(from, to)
    create(:location_connection, location: from, connected_location: to,
                                 distance: "adjacent", travel_method: "walking")
    create(:location_connection, location: to, connected_location: from,
                                 distance: "adjacent", travel_method: "walking")
  end

  # One line, played by the engine with no model.
  def play(command) = EngineSweep::RustMechanics.new(@playthrough.reload).run(command)

  test "the read-out matches the database after every command of the walk" do
    [ "look", "take stamp", "go closet", "drop stamp", "take index", "go ward office", "go hallway" ].each do |command|
      assert_reads_true play(command), command
    end
  end

  test "the read-out says nobody is hostile in an ordinary room" do
    report = play("look")

    assert_equal [ @rowe ], report.state.present
    assert_equal [], report.state.foes
    assert_includes report.to_s, "nobody is fighting you"
  end

  test "the read-out names a foe standing here, beside the cast it is part of" do
    marek = create(:character, :monster, story: @story, location: @office, fullname: "Marek Sollen")

    report = play("look")

    assert_equal [ @rowe, marek ], report.state.present
    assert_equal [ marek ], report.state.foes
    assert_match(/foes\s+Marek Sollen/, report.to_s)
    assert_match(/present\s+Halkett Rowe, Marek Sollen/, report.to_s)
  end

  test "a foe in the next room is not a foe in this one" do
    create(:character, :monster, story: @story, location: @closet, fullname: "Marek Sollen")

    assert_equal [], play("look").state.foes
    assert_equal [ "Marek Sollen" ], play("go closet").state.foes.map(&:fullname)
  end

  test "the read-out carries the player's condition" do
    assert_includes play("look").state.to_s, "condition   unhurt"
  end

  test "the read-out says which reader answered" do
    report = play("/take the ward stamp")

    assert_includes report.to_s, "read by:    grammar"
  end

  test "the read-out carries the world's own numbers for the player" do
    @vance.update!(level: 1, hit_die: 6, strength: 9, dexterity: 11, will: 15)

    read_out = play("stats").state.to_s

    assert_includes read_out, "sheet       level 1, d6, strength 9 dexterity 11 will 15"
  end

  test "the read-out tells a provoked foe apart from a hostile one" do
    tough!(@vance, @rowe)
    play("/attack Halkett Rowe")

    assert_match(/foes\s+Halkett Rowe/, play("look").to_s)
    assert_match(/provoked\s+Halkett Rowe/, play("look").to_s)
  end

  test "the read-out says how much is left of everybody standing here" do
    tough!(@vance, @rowe)
    play("/attack Halkett Rowe")

    assert_match(/others\s+Halkett Rowe (hurt|badly hurt|dead)/, play("look").to_s)
  end

  test "the read-out says a safe room is safe and its ways out are free" do
    state = play("look").state.to_s

    assert_match(/hazard\s+nothing here hurts you/, state)
    assert_match(/hazards out\s+every way out of here is free/, state)
  end

  test "the read-out prints the whole of a room's hazard entry" do
    @office.update!(hazard: "flooded", hazard_die: 4)

    assert_match(/hazard\s+flooded d4, strength save, on arrival -- the water takes your legs/,
                 play("look").state.to_s)
  end

  test "a hazard with no save says so rather than naming one" do
    @office.update!(hazard: "airless", hazard_die: 6)

    assert_match(/hazard\s+airless d6, no save, every turn/, play("look").state.to_s)
  end

  test "the read-out names the way out that costs something and not the way back" do
    LocationConnection.walked(@office, @closet).update!(hazard: "drop", hazard_die: 4)

    assert_match(/hazards out\s+The Supply Closet: drop d4, dexterity save/, play("look").state.to_s)

    play("go to the supply closet")
    assert_match(/hazards out\s+every way out of here is free/, play("look").state.to_s,
                 "the return row carries no hazard, so leaving the closet is free")
  end

  private

  def tough!(*people)
    people.each { |person| person.update!(level: 3) }
    @playthrough.vitals.destroy_all
    Playthrough::Snapshot.new(@playthrough).of_the_room!(@playthrough.current_location)
  end

  def assert_reads_true(report, command)
    @playthrough.reload
    state = report.state
    here = @playthrough.current_location
    who = @playthrough.character
    where = "after #{command.inspect}"

    # `nil` on either side is a real state -- a playthrough can stand nowhere and
    # can have no protagonist -- and both are empty sets rather than "everything
    # whose column is null", which is what an unguarded scope would answer.
    if here.nil?
      assert_nil state.location, where
    else
      assert_equal here, state.location, where
    end

    assert_equal here ? here.exits.order(:id).to_a : [], state.exits, where
    # THIS GAME'S FLOOR, not the world's. `Item.lying_in` reaches both layers,
    # and the read-out prints the closed set `take` resolves against, which is
    # this playthrough's own copies (`Playthrough#items_lying_in`).
    assert_equal @playthrough.items_lying_in(here).to_a, state.items_here, where
    assert_equal @playthrough.carried.to_a, state.carried, where

    state.items_here.each { |item| assert_equal here, item.reload.location, where }
    state.carried.each { |item| assert_predicate item.reload, :carried?, where }
    state.carried.each { |item| assert_equal @playthrough, item.playthrough, where }

    # And the printed block names them, so a read-out cannot be right in the
    # records and wrong on the screen.
    (state.items_here + state.carried).each { |item| assert_includes report.to_s, item.name, where }
    state.exits.each { |exit| assert_includes report.to_s, exit.name, where }

    # WHO IS HERE AND WHICH OF THEM MEANS THE PARTY HARM, and they are two
    # answers: the read-out prints both rows, so a foe that stopped being in the
    # cast or a bystander that started being a foe fails here.
    #
    # NOWHERE IS AN EMPTY SET on both, and it is asserted rather than derived --
    # `Character.present_in(nil)` is "everybody whose whereabouts is nobody's
    # business", which is the unguarded scope's answer and not this room's.
    assert_equal here ? Character.present_in(here).to_a : [], state.present, where
    assert_equal here ? @playthrough.foes_in(here) : [], state.foes, where
    assert_equal [], state.foes - state.present, where
  end
end
