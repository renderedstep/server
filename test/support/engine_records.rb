# THE RECORDS A TURN LEAVES, WRITTEN BY A TEST THAT WANTS THE RECORDS.
#
# The Rust engine is the only writer of a wound, a blow or a thing taken into
# the party's hands in play. A test whose subject is a READER of those rows --
# what a prompt is told, what the panels show, what the doctor or the audit
# finds -- wants the state and not the turn that produced it, so it writes the
# rows here, as a factory writes any other row, and stays in its transaction.
# A test about how a turn writes them plays one on the engine instead
# (`PlaysOnRust`, or a sweep script).
#
# Every helper writes exactly the columns the engine writes for the same fact,
# and rolls no die: a test that needs an amount says it.
module EngineRecords
  # Hit points off a body in one game. A body brought to zero is dead in the
  # same statement the engine makes: a person other than the player keeps
  # their body where they fell (`Playthrough#keep_npc_body!`), and the
  # player's game ends (`Playthrough#end!`). What a body was holding stays in
  # its hands; a test that wants it on the floor puts it there. Answers the
  # condition afterwards, or nil for a body with no stat block.
  def wound!(playthrough, character, amount)
    row = Playthrough::Vitals.instantiate!(playthrough, character)
    return nil if row.nil?

    row.update!(hp_current: [ row.hp_current - amount.to_i, 0 ].max)
    if row.dead?
      playthrough.keep_npc_body!(character)
      playthrough.end! if character == playthrough.character
    end
    row.condition
  end

  # One blow landed: `damage` off the target, the target this game's foe from
  # now on, and the blow's row -- numbered after the game's blows so far, as
  # the engine numbers them. Answers the blow.
  def blow!(playthrough, attacker, target, damage:, round: 1, room: playthrough.current_location)
    after = wound!(playthrough, target, damage)
    Playthrough::Vitals.instantiate!(playthrough, target)&.provoke!(playthrough.story_now)
    Playthrough::Blow.create!(
      playthrough: playthrough, attacker: attacker, target: target, location: room,
      damage: damage, hp_after: after.hp, round: round,
      sequence: Character::ABILITIES.size + 1 + Playthrough::Blow.next_sequence(playthrough),
      story_timestamp: playthrough.story_now
    )
  end

  # The scene that closes a fight: written after the game's open blows, a
  # story turn per round fought, and claiming them, as the engine closes one.
  # Answers the scene.
  def fight_closed!(playthrough, description: "The fight is over.")
    blows = playthrough.blows.open.to_a
    rounds = blows.map(&:round).uniq.size
    scene = create(:scene, story: playthrough.story, location: playthrough.current_location,
                           previous_scene: playthrough.current_scene, description: description,
                           resolved_action: "attack",
                           story_timestamp: playthrough.story_now + (Scene::TURN_MINUTES.fetch("action") * rounds).minutes)
    Playthrough::Blow.where(id: blows.map(&:id)).update_all(scene_id: scene.id)
    playthrough.update!(current_scene: scene)
    scene
  end

  # A thing in the party's hands: this game's copy, in no room and no hand,
  # off the floor plan.
  def carried!(playthrough, item)
    item.update!(playthrough: playthrough, character: nil, location: nil, **Item.lifted)
    item
  end
end

ActiveSupport::TestCase.include(EngineRecords)
