# frozen_string_literal: true

# ledger_id leads because it's always an equality filter (a specific ledger's
# pins); pinned_at trails as the existence check (IS NOT NULL). Leading with
# the equality column lets Postgres seek straight to that ledger's slice of
# the index before filtering out the (overwhelmingly common) unpinned rows,
# rather than scanning across every ledger's pinned rows to find this one's.
class AddIndexOnLedgerIdAndPinnedAtToLedgerMappings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :ledger_mappings, [:ledger_id, :pinned_at], algorithm: :concurrently
  end

end
