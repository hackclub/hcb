# frozen_string_literal: true

module Maintenance
  # Mirrors HcbCode#marked_no_or_lost_receipt_at onto its Ledger::Item for
  # transactions marked (or unmarked) before HcbCode started syncing the change
  # itself. Ledger items keep their own copy for Ledger::Item#missing_receipt?
  # and the ledger filters, so a stale copy shows a resolved transaction as
  # missing a receipt (or vice versa).
  #
  # Only mismatched pairs are collected — `IS DISTINCT FROM` so a mark present on
  # one side and absent on the other counts as a mismatch — which makes reruns
  # cheap and lets the task be safely restarted.
  class BackfillLedgerItemNoOrLostReceiptsTask < MaintenanceTasks::Task
    def collection
      HcbCode.where(id: mismatched)
    end

    def process(hcb_code)
      hcb_code.sync_marked_no_or_lost_receipt_at_to_ledger_item
    end

    private

    def mismatched
      HcbCode
        .joins(:ledger_item)
        .where("hcb_codes.marked_no_or_lost_receipt_at IS DISTINCT FROM ledger_items.marked_no_or_lost_receipt_at")
        .select(:id)
    end

  end
end
