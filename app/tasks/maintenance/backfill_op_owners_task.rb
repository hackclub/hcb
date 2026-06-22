# frozen_string_literal: true

module Maintenance
  class BackfillOpOwnersTask < MaintenanceTasks::Task
    def collection
      OrganizerPosition.joins(:fiscal_sponsorship_contract).where(is_signee: true, fiscal_sponsorship_contract: { aasm_state: "signed" })
    end

    def process(op)
      op.update!(role: :owner)
    end

  end
end
