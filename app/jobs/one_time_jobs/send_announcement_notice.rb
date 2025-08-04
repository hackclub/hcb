# frozen_string_literal: true

module OneTimeJobs
  class SendAnnouncementNotice < ApplicationJob
    def self.perform
      # Rate limit is 14/s, but putting 12 here to be safe and allow for other emails to be sent
      queue = Limiter::RateQueue.new(12, interval: 1)

      Event.includes(:config).where(config: { generate_monthly_announcement: true }).find_each do |event|
        queue.shift
        AnnouncementMailer.with(event:).notice.deliver_now
      end
    end

  end

end
