# frozen_string_literal: true

module Maintenance
  class BackfillLedgerItemCustomMemosTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.all
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
