# frozen_string_literal: true

module Maintenance
  # Populates Ledger::Item#pending_at and #settled_at, and corrects #datetime,
  # which until now was frozen at whatever the item's first CT/CPT happened to
  # be created at.
  #
  # Only items with a transaction to derive a timestamp from are visited; the
  # rest have nothing to backfill and keep the datetime they were created with.
  # Membership is checked against the transactions themselves rather than the
  # ct_count/cpt_count caches, which are only correct on items that have been
  # refreshed since those columns were added.
  class BackfillLedgerItemTimestampsTask < MaintenanceTasks::Task
    HAS_TRANSACTIONS = <<~SQL.squish
      EXISTS (SELECT 1 FROM canonical_transactions WHERE canonical_transactions.ledger_item_id = ledger_items.id)
      OR EXISTS (SELECT 1 FROM canonical_pending_transactions WHERE canonical_pending_transactions.ledger_item_id = ledger_items.id)
    SQL

    def collection
      Ledger::Item.where(pending_at: nil, settled_at: nil).where(HAS_TRANSACTIONS)
    end

    def process(ledger_item)
      ledger_item.refresh_timestamps!
    end

  end
end
