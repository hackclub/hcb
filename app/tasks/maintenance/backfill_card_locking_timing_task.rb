# frozen_string_literal: true

module Maintenance
  # Populates persisted card-locking timing (receipt_settled_at / receipt_due_at /
  # receipt_resolved_at) for every existing relevant charge, via the idempotent
  # materializer. receipt_due_at is set here too, so old outstanding charges are
  # immediately overdue at launch rather than excluded from trust.
  class BackfillCardLockingTimingTask < MaintenanceTasks::Task
    def collection
      HcbCode.where(id: HcbCode.card_locking_relevant.select(:id))
    end

    def process(hcb_code)
      hcb_code.materialize_card_locking!
    end

  end
end
