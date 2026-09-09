# frozen_string_literal: true

module Maintenance
  # Populates Ledger::Item#pending_at and #settled_at, and corrects #datetime,
  # which until now was frozen at whatever the item's first CT/CPT happened to
  # be created at.
  #
  # Writes with update_columns so only the timestamps change: a full refresh!
  # would rewrite every other cached column and leave a PaperTrail version
  # behind on every item. The calculation has to mirror Ledger::Item#refresh!,
  # so keep the two in step.
  class BackfillLedgerItemTimestampsTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.all
    end

    def process(ledger_item)
      pending_at = ledger_item.canonical_pending_transactions.order(:date, :id).first&.datetime
      settled_at = ledger_item.canonical_transactions.order(:date, :id).last&.datetime

      ledger_item.update_columns(
        pending_at:,
        settled_at:,
        datetime: settled_at || pending_at || ledger_item.datetime
      )
    end

  end
end
