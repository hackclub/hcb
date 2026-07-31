# frozen_string_literal: true

module Maintenance
  class BackfillTransactionCountLedgerItemsTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.all
    end

    def process(ledger_item)
      ledger_item.ct_count = ledger_item.canonical_transactions.count
      ledger_item.cpt_count = ledger_item.canonical_pending_transactions.count
      ledger_item.save!
    end

  end
end
