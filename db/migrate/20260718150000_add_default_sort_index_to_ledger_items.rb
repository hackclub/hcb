# frozen_string_literal: true

class AddDefaultSortIndexToLedgerItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Matches Ledger::Query#execute's default ORDER BY exactly (including sort
    # direction per column) so a paginated fetch can walk this index in order
    # and stop once it has enough rows, instead of sorting every matching row
    # first.
    add_index :ledger_items,
              "(CASE WHEN (status = 'pending') THEN 0 ELSE 1 END), datetime DESC, created_at DESC, id DESC",
              name: "index_ledger_items_on_default_sort",
              algorithm: :concurrently
  end

end
