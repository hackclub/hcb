# frozen_string_literal: true

module DisbursementService
  class Hourly
    def run
      Disbursement.where(aasm_state: :in_transit).each do |disbursement|
        if disbursement.canonical_transactions.size == 2
          disbursement.mark_deposited!
        elsif disbursement.canonical_transactions.size > 2
          Airbrake.notify("Disbursement #{disbursement.id} has more than 2 canonical transactions!")
        end
      end
    end

  end
end
