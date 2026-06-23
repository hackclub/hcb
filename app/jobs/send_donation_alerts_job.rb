# frozen_string_literal: true

class SendDonationAlertsJob < ApplicationJob
  queue_as :default

  def perform(donation_id)
    donation = Donation.find(donation_id)
    ::DonationService::Alert.new(donation).run
  rescue => e
    Rails.logger.error("Error sending donation alerts for donation #{donation_id}: #{e.message}")
    raise e
  end

end
