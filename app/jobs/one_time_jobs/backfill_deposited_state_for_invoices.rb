# frozen_string_literal: true

module OneTimeJobs
  class BackfillDepositedStateForInvoices
    queue_as :default

    def perform
      Invoice.find_each do |invoice|
        if invoice.deposited?
          invoice.mark_deposited!
        end
      end
    end

  end
end
