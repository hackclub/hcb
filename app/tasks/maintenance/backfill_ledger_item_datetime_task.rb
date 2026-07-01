# frozen_string_literal: true

module Maintenance
  # Backfills Ledger::Item#datetime from the legacy #date column during the
  # date -> datetime rename. Run this after deploying the column add (and its
  # sync callback) and before enforcing NOT NULL on datetime.
  #
  # Processed in batches so each iteration is a single UPDATE rather than a
  # query per row.
  class BackfillLedgerItemDatetimeTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.where(datetime: nil).in_batches(of: 1000)
    end

    def process(batch)
      batch.update_all("datetime = date")
    end

  end
end
