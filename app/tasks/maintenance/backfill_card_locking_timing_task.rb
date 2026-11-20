# frozen_string_literal: true

module Maintenance
  # Populates the persisted card-locking deadline (receipt_due_at) for every
  # existing relevant charge, via the idempotent materializer. receipt_due_at is
  # set only for charges settled on or after the enforcement start date; older
  # charges get no due date, so they are never overdue (receipt_trusted? still
  # counts their receipts against a synthesized settled_at + 7 days).
  #
  # Not needed for the lock decision: the five-minute sweep materializes every
  # charge still missing a receipt on its own. This also covers the resolved
  # history receipt_trusted? reads, which the sweep never visits.
  class BackfillCardLockingTimingTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.where(id: Ledger::Item.card_locking_relevant.select(:id))
    end

    def process(ledger_item)
      ledger_item.materialize_card_locking!
    end

  end
end
