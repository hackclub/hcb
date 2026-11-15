# frozen_string_literal: true

class AddCardLockingReceiptTimingIndexesToLedgerItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Lock lookups hit "outstanding (unresolved) and due"; a partial index keeps it small.
    add_index :ledger_items, :receipt_due_at,
              where: "receipt_due_at IS NOT NULL AND receipt_resolved_at IS NULL",
              name: "index_ledger_items_on_open_receipt_due_at",
              algorithm: :concurrently
    add_index :ledger_items, :card_charge_settled_at, algorithm: :concurrently
  end

end
