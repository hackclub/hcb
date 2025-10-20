# frozen_string_literal: true

class EventMailerPreview < ActionMailer::Preview
  def monthly_donation_summary
    EventMailer.with(event: Donation.last.event).monthly_donation_summary
  end

  def donation_goal_reached
    EventMailer.with(event: Donation::Goal.last.event).donation_goal_reached
  end

  def monthly_follower_summary
    EventMailer.with(event: Event::Follow.last.event).monthly_follower_summary
  end

  def negative_balance
    EventMailer
      .with(
        event: Event.first,
        balance: -123_45,
      )
      .negative_balance
  end

end
