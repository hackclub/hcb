# frozen_string_literal: true

class AddCardLockingReceiptTimingIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Lock lookups hit "outstanding (unresolved) and due"; a partial index keeps it small.
    add_index :hcb_codes, :receipt_due_at,
              where: "receipt_due_at IS NOT NULL AND receipt_resolved_at IS NULL",
              name: "index_hcb_codes_on_open_receipt_due_at",
              algorithm: :concurrently
    add_index :hcb_codes, :card_charge_settled_at, algorithm: :concurrently
  end
end
