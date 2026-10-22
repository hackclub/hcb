# frozen_string_literal: true

module Maintenance
  # Recomputes the cached columns (amount, memos, author, counts, receipt
  # requirement) on every Ledger::Item, refreshing all ledgers. Items are
  # processed directly (rather than per ledger) so an item mapped to
  # multiple ledgers is only refreshed once.
  class RefreshLedgerItemsTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.all
    end

    def process(ledger_item)
      ledger_item.refresh!
    end

  end
end
