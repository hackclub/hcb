# frozen_string_literal: true

module OneTimeJobs
  class BackfillDepositedStateForInvoices < ApplicationJob
    queue_as :default

    def perform
      Invoice.where(aasm_state: :paid_v2).find_each do |invoice|
        if invoice.deposited?
          invoice.mark_deposited!
        end
      end
    end

  end
end
