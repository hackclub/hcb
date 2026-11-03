# frozen_string_literal: true

module Maintenance
  class MovePayrollPositionsToDraftTask < MaintenanceTasks::Task
    def collection
      Payroll::Position.where(aasm_state: [:under_review, :onboarding])
    end

    def process(position)
      unless position.contract_signed_by?(:organizer)
        position.update!(aasm_state: :draft)
      end
    end

  end
end
