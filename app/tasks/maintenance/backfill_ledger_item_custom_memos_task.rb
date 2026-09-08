# frozen_string_literal: true

module Maintenance
  class BackfillLedgerItemCustomMemosTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.where(id: CanonicalTransaction.where.not(custom_memo: nil).select(:ledger_item_id)).or(Ledger::Item.where(id: CanonicalPendingTransaction.where.not(custom_memo: nil).select(:ledger_item_id)))
    end

    def process(ledger_item)
      if ledger_item.hcb_code&.custom_memo.present?
        ledger_item.custom_memo = ledger_item.hcb_code.custom_memo
        ledger_item.memo = ledger_item.custom_memo
        ledger_item.save!
      end
    end

  end
end
