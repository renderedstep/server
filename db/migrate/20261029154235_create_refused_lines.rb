# THE REFUSAL CORPUS: one row for each free-typed line the local reader's
# reading refused, kept so the reader can be relabelled and retrained on the
# lines it could not read. The owner's ruling of 2026-10-29: "always refuse and
# ask, we should track refusals so we can try to improve the model with them in
# the future". The engine writes it (renderedstep/engine `keep_refusal`, in the
# turn's own transaction); `RefusedLine` is what belongs here about why.
#
# THE ENGINE'S COLUMNS, TO THE TYPE. The engine writes exactly these, and reads
# a column's declared type to know how to write it, so `json` and `float` are
# the types it needs. It treats the table as optional (`store::OPTIONAL`): it is
# not in the shape the engine checks, so a database without it still plays, and
# only a host that asks to keep lines needs it.
#
# NO FOREIGN KEY, ON PURPOSE. A row outlives the game it was typed in, so
# `playthrough_id` and `location_id` are plain integers, for jumping back to the
# game while it exists. The row stands on its own without them: `state` is the
# whole of what the reader was shown.
class CreateRefusedLines < ActiveRecord::Migration[8.1]
  def change
    create_table :refused_lines do |t|
      t.text :typed, null: false
      t.json :state, null: false
      t.json :answers
      t.json :reading, null: false
      t.float :act_confidence
      t.float :thing_confidence
      t.json :refusal, null: false
      t.string :place
      t.string :weights
      t.integer :playthrough_id
      t.integer :location_id
      t.string :status, null: false, default: "new"
      t.json :label
      t.datetime :labelled_at
      t.text :note
      t.timestamps
    end
    add_index :refused_lines, :status
  end
end
