# frozen_string_literal: true

module DonationJob
  class Refund < ApplicationJob
    queue_as :default
    def perform(donation, amount)
      return if donation.refunded?

      if donation.canonical_transactions.any?
        DonationService::Refund.new(donation_id: donation.id, amount:).run
      else
        DonationJob::Refund.set(wait: 1.day).perform_later(donation, amount)
      end
    end

  end
end
