# frozen_string_literal: true

module PayoutService
  class Nightly
    def run
      ::Donation.where(aasm_state: [:in_transit, :refunded]).missing_payout.find_each(batch_size: 100) do |donation|
        ::Payout::DonationJob.perform_later(donation.id)
      end

      ::Invoice.paid_v2.missing_payout.find_each(batch_size: 100) do |invoice|
        ::Payout::InvoiceJob.perform_later(invoice.id)
      end
    end

  end
end
