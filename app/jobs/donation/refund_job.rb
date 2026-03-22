# frozen_string_literal: true

class Donation
  class RefundJob < ApplicationJob
    queue_as :default
    def perform(donation, amount, requested_by, reason = nil)
      return if donation.refunded?

      if donation.canonical_transactions.any?
        DonationService::Refund.new(donation_id: donation.id, amount:, reason:).run
        DonationMailer.with(donation:, requested_by:).refunded.deliver_later if requested_by
      else
        Donation::RefundJob.set(wait: 1.day).perform_later(donation, amount, requested_by, reason)
      end
    end

  end

end
