# frozen_string_literal: true

module Maintenance
  # Moves the receipts still attached to an HCB code onto its ledger item,
  # finishing the move of receipts from HcbCode to Ledger::Item
  # (https://github.com/hackclub/hcb/issues/14106). New receipts already go to
  # the ledger item (Receipt's before_validation), and a code hands its
  # receipts over the moment it is linked to an item
  # (HcbCode#move_receipts_to_ledger_item!); this catches the pairs linked
  # before either existed.
  #
  # HCB codes with no ledger item are left alone. In production those are the
  # empty HCB-000 codes with no transactions, which will never get one; their
  # receipts stay on the code, where Receiptable#receipts still reads them.
  #
  # The collection only holds codes that still have a receipt of their own, so
  # it shrinks as the task runs: reruns are cheap and an interrupted run can be
  # restarted. The hand-over itself is an update_all (see
  # HcbCode#move_receipts_to_ledger_item!), so the pairing and card-locking
  # receipt callbacks don't fire for every moved row, and the item's cached
  # receipt_count is refreshed by hand.
  class MoveHcbCodeReceiptsToLedgerItemsTask < MaintenanceTasks::Task
    def collection
      HcbCode
        .where.not(ledger_item_id: nil)
        .where(id: Receipt.where(receiptable_type: "HcbCode").select(:receiptable_id))
        .includes(:ledger_item)
    end

    def process(hcb_code)
      hcb_code.move_receipts_to_ledger_item!
    end

  end
end
