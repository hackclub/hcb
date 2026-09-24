# frozen_string_literal: true

module Maintenance
  class AssignLedgerItemLinkedObjectsTask < MaintenanceTasks::Task
    def collection
      Ledger::Item.where(linked_object_id: nil)
    end

    def process(ledger_item)
      ledger_item.send(:assign_linked_object!)
    end

  end
end
