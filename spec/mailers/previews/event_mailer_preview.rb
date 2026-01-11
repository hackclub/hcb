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

  def transparency_mode_enabled
    EventMailer.with(event: Event.first, whodunnit: Event.first.users.first).transparency_mode_enabled
  end

  def monthly_announcements_enabled
    EventMailer.with(event: Announcement.monthly_for(Date.today).first.event, whodunnit: Event.first.users.first).monthly_announcements_enabled
  end

  def transparency_mode_disabled
    EventMailer.with(event: Event.first, whodunnit: Event.first.users.first).transparency_mode_disabled
  end

  def monthly_announcements_disabled
    EventMailer.with(event: Event.first, whodunnit: Event.first.users.first).monthly_announcements_disabled
  end

end
