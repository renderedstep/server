# The version is the engine's `SCHEMA_VERSION` (renderedstep/engine#58), not a
# generated second: the engine opens a database only at the version and shape
# it was written against, so this migration has to carry exactly that number.
class AddCostSourceToSystemOneReceipts < ActiveRecord::Migration[8.1]
  def change
    add_column :system_one_receipts, :cost_source, :string, null: false, default: "estimated"
  end
end
