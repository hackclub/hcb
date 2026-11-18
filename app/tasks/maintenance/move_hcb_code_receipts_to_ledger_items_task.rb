# frozen_string_literal: true

module Maintenance
  # Moves the receipts still attached to an HCB code onto its ledger item,
  # finishing the move of receipts from HcbCode to Ledger::Item
  # (https://github.com/hackclub/hcb/issues/14106). New receipts already go to
  # the ledger item, every caller attaches to it directly; this catches the
  # rows attached to a code before it had an item.
  #
  # HCB codes with no ledger item are left alone. In production those are the
  # empty HCB-000 codes with no transactions, which will never get one. Their
  # receipt rows stay on the code, though HcbCode#receipts, which reads through
  # the ledger item, no longer surfaces them.
  #
  # The collection only holds codes that still have a receipt of their own, so
  # it shrinks as the task runs: reruns are cheap and an interrupted run can be
  # restarted.
  #
  # The hand-over is an update_all rather than update!: the receipt isn't
  # changing, only which of the transaction's two records it hangs off, so the
  # pairing and card-locking receipt callbacks (an unlock job per charge) have
  # nothing to do. It also skips the touch that would refresh the item, so the
  # item's cached receipt_count is recounted by hand: just that column, not a
  # full refresh!, since that is the only thing the move changes.
  class MoveHcbCodeReceiptsToLedgerItemsTask < MaintenanceTasks::Task
    def collection
      HcbCode
        .where.not(ledger_item_id: nil)
        .where(id: Receipt.where(receiptable_type: "HcbCode").select(:receiptable_id))
    end

    def process(hcb_code)
      moved = Receipt.where(receiptable: hcb_code).update_all(receiptable_type: "Ledger::Item", receiptable_id: hcb_code.ledger_item_id)
      return unless moved.positive?

      receipt_count = Receipt.where(receiptable_type: "Ledger::Item", receiptable_id: hcb_code.ledger_item_id).count
      Ledger::Item.where(id: hcb_code.ledger_item_id).update_all(receipt_count:)
    end

  end
end
