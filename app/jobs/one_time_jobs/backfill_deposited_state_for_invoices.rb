# frozen_string_literal: true

module OneTimeJobs
  class BackfillDepositedStateForInvoices
    queue_as :default

    def perform
      Invoice.find_in_batches(batch_size: 100) do |batch|
        batch.each do |invoice|
          if invoice.deposited?
            invoice.update_column(:aasm_state, :deposited_v2)
          end
        end
      end
    end

  end
end
