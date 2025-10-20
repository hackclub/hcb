# frozen_string_literal: true

module OneTimeJobs
  class SendAnnouncementNotice < ApplicationJob
    def perform
      Event.includes(:config).where(config: { generate_monthly_announcement: true }).find_each do |event|
        monthly_announcement = event.announcements.monthly.last

        if monthly_announcement.present?
          AnnouncementMailer.with(event:, monthly_announcement:).notice.deliver_later
        end
      end
    end

  end

end
