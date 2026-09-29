# frozen_string_literal: true

module Maintenance
  # Populates Ledger::Item#receipt_count for reimbursement payouts, which until
  # now counted the receipts on the payout's HCB code (always none) rather than
  # the ones uploaded to the expense itself, so the ledger showed no receipt
  # badge for any reimbursement.
  #
  # Writes with update_column so only the count changes: a full refresh! would
  # rewrite every other cached column and leave a PaperTrail version behind on
  # every item.
  class BackfillReimbursementLedgerItemReceiptCountsTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.where(linked_object_type: "Reimbursement::ExpensePayout")
    end

    def process(ledger_item)
      # Private on Ledger::Item, but reused rather than reimplemented here so
      # this can't drift from refresh!.
      receipt_count = ledger_item.send(:calculate_receipt_count)

      ledger_item.update_column(:receipt_count, receipt_count) if ledger_item.receipt_count != receipt_count
    end

  end
end
