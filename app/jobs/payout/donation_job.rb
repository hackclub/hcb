# frozen_string_literal: true

module Payout
  class DonationJob < ApplicationJob
    queue_as :default
    def perform(donation_id)
      ::PayoutService::Donation::Create.new(donation_id:).run
    end

  end
end

module PayoutJob
  Donation = Payout::DonationJob
end
