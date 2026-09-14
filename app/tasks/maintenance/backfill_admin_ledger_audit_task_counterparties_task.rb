# frozen_string_literal: true

module Maintenance
  # One-time backfill: derives ledger_item_id from hcb_code_id on existing
  # Admin::LedgerAudit::Task records (all created before ledger_item_id
  # existed), mirroring the before_create callback added alongside the
  # column.
  class BackfillAdminLedgerAuditTaskCounterpartiesTask < MaintenanceTasks::Task
    def collection
      Admin::LedgerAudit::Task.where(ledger_item_id: nil)
    end

    def process(task)
      return if task.hcb_code_id.nil?

      task.update!(ledger_item_id: task.hcb_code.ledger_item_id)
    end

  end
end
