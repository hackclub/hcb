# frozen_string_literal: true

module Maintenance
  # Populates persisted card-locking timing (receipt_due_at / receipt_resolved_at)
  # for every existing relevant charge, via the idempotent materializer.
  # receipt_due_at is set only for charges settled on or after the enforcement
  # start date; older charges get resolved timing (so they still count toward
  # trust) but no due date, so they are never overdue.
  class BackfillCardLockingTimingTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.where(id: Ledger::Item.card_locking_relevant.select(:id))
    end

    def process(ledger_item)
      ledger_item.materialize_card_locking!
    end

  end
end
