# frozen_string_literal: true

module DisbursementService
  class Hourly
    def run
      Disbursement.in_transit.find_each(batch_size: 100) do |disbursement|
        if disbursement.canonical_transactions.size == 2
          disbursement.mark_deposited!
        elsif disbursement.canonical_transactions.size > 2
          Rails.error.unexpected "Disbursement #{disbursement.id} has more than 2 canonical transactions!"
        end
      end
    end

  end
end
