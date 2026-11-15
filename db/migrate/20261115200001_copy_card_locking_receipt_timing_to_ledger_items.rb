# frozen_string_literal: true

# Copies the persisted card-locking timing from each HCB code onto its ledger
# item, which owns it from this deploy on. Run as a migration rather than a
# maintenance task so that no deploy ever sees the ledger item columns empty:
# until they are filled no charge is overdue, so the five-minute sweep
# (User::UpdateCardLocking::RecurringJob) would unlock every locked cardholder
# and tell them their cards work again. Batched so no single statement holds
# row locks for long.
class CopyCardLockingReceiptTimingToLedgerItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class HcbCode < ActiveRecord::Base
    self.table_name = "hcb_codes"

  end

  def up
    HcbCode.where.not(ledger_item_id: nil)
           .where("receipt_due_at IS NOT NULL OR receipt_resolved_at IS NOT NULL")
           .in_batches(of: 1_000) do |batch|
      safety_assured do
        execute(<<~SQL.squish)
          UPDATE ledger_items
          SET receipt_due_at = hcb_codes.receipt_due_at,
              receipt_resolved_at = hcb_codes.receipt_resolved_at
          FROM hcb_codes
          WHERE hcb_codes.ledger_item_id = ledger_items.id
            AND hcb_codes.id IN (#{batch.select(:id).to_sql})
        SQL
      end
    end
  end

  def down
    # Nothing to undo: the columns' own migration removes them.
  end

end
