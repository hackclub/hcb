# frozen_string_literal: true

module OneTimeJobs
  class SendAnnouncementNotice < ApplicationJob
    def self.perform
      # Rate limit is 14/s, but putting 12 here to be safe and allow for other emails to be sent
      queue = Limiter::RateQueue.new(12, interval: 1)

      Event.find_each do |event|
        queue.shift

        if should_enable_monthly_announcements(event) && !event.config.generate_monthly_announcement
          event.config.update!(generate_monthly_announcement: true)
          monthly_announcement = Announcement::Templates::Monthly.new(event:, author: User.system_user).create
          AnnouncementMailer.with(event:, monthly_announcement:).notice.deliver_now
        else
          AnnouncementMailer.with(event:).notice.deliver_now
        end
      end
    end

    def self.should_enable_monthly_announcements(event)
      has_donation_goal = event.donation_goal.present?
      has_recent_merchants = BreakdownEngine::Merchants.new(event, timeframe: 1.month).run.any?
      has_recent_donations = event.donations.any? { |donation| donation.created_at > 1.month.ago }

      event.is_public && (has_donation_goal || has_recent_merchants || has_recent_donations)
    end

  end

end
