# frozen_string_literal: true

class EventMailerPreview < ActionMailer::Preview
  def monthly_donation_summary
    EventMailer.with(event: Donation.last.event).monthly_donation_summary
  end

end
