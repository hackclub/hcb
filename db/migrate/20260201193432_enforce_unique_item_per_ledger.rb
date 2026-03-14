# frozen_string_literal: true

class EnforceUniqueItemPerLedger < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Add unique index to enforce one mapping per (ledger, item) pair
    # This applies to ALL ledgers (primary and non-primary)
    # The existing partial unique index (index_ledger_mappings_unique_item_on_primary)
    # already enforces one primary mapping per item across all ledgers
    add_index :ledger_mappings, [:ledger_id, :ledger_item_id],
              unique: true,
              name: "index_ledger_mappings_on_ledger_and_item",
              algorithm: :concurrently
  end
end
