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
      # filter more
      event.is_public
    end

  end

end
