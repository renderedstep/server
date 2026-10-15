# The version is the engine's `SCHEMA_VERSION` (renderedstep/engine#59), not a
# generated second: the engine opens a database only at the version and shape
# it was written against, so this migration has to carry exactly that number.
class AddLatencyMsToModelReceipts < ActiveRecord::Migration[8.1]
  def change
    add_column :system_one_receipts, :latency_ms, :integer
    add_column :ruby_llm_usages, :latency_ms, :integer
  end
end
