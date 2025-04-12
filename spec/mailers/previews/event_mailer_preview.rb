# frozen_string_literal: true

class EventMailerPreview < ActionMailer::Preview
  def monthly_donation_summary
    EventMailer.with(event: Event.not_demo_mode.first).monthly_donation_summary
  end

end
