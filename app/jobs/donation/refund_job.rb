# frozen_string_literal: true

class Donation
  class RefundJob < ApplicationJob
    queue_as :default
    def perform(donation, amount, requested_by)
      return if donation.refunded?

      if donation.canonical_transactions.any?
        DonationService::Refund.new(donation_id: donation.id, amount:).run
        DonationMailer.with(donation:, requested_by:).refunded.deliver_later if requested_by
      else
        DonationJob::Refund.set(wait: 1.day).perform_later(donation, amount, requested_by)
      end
    end

  end

end

module DonationJob
  Refund = Donation::RefundJob
end
