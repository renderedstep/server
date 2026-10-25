# WHETHER WHAT A BODY CAN HOLD IS LIMITED IN THIS WORLD. The engine reads it
# (renderedstep/engine `carry.rs`); what belongs here is why the column has
# the shape it has.
#
# THE ENGINE'S MIGRATION, TO THE BYTE. The Rust engine checks the schema it
# opens against the one it was written for (`RenderedStep::SCHEMA_VERSION`, and
# the shape of every table it touches), so its version and column are the
# engine's, generated and then given that version. A column added here alone
# would make the engine refuse every turn.
#
# ONE OF `Universe::CARRYINGS`, OR NOTHING. `limited` turns the carrying rule
# on: a take, a throw of a thing lying in the room, or a break-off that would
# put in hand what does not fit is refused, and nobody is offered a take or a
# give of what would not fit the one who would hold it.
#
# NULLABLE AND NOT BACKFILLED. Nil plays exactly as before, so every world that
# exists, and every game in one, plays as it did. A new parameter ships inert.
class AddCarryingToUniverses < ActiveRecord::Migration[8.1]
  def change
    add_column :universes, :carrying, :string
  end
end
