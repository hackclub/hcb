# frozen_string_literal: true

module Maintenance
  class ScheduleContractOperationsUpdatesTask < MaintenanceTasks::Task
    def collection
      Contract::FiscalSponsorship.where(aasm_state: :sent)
    end

    def process(contract)
      due_at = contract.created_at + Contract::FiscalSponsorship::OPERATIONS_UPDATE_AFTER

      if due_at.future?
        Contract::OperationsUpdateJob.set(wait_until: due_at).perform_later(contract)
      else
        Contract::OperationsUpdateJob.perform_later(contract)
      end
    end

  end
end
