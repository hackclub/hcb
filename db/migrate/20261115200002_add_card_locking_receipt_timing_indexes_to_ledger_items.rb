# frozen_string_literal: true

class AddCardLockingReceiptTimingIndexesToLedgerItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Lock lookups hit "outstanding (no receipt, not marked no/lost) and due";
    # a partial index keeps it small. Matches Ledger::Item.receipt_overdue.
    add_index :ledger_items, :receipt_due_at,
              where: "receipt_due_at IS NOT NULL AND receipt_count = 0 AND marked_no_or_lost_receipt_at IS NULL",
              name: "index_ledger_items_on_open_receipt_due_at",
              algorithm: :concurrently
  end

end
