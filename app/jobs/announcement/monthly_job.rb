# frozen_string_literal: true

class Announcement
  class MonthlyJob < ApplicationJob
    queue_as :default

    def perform
      Announcement.monthly_for(Date.today.prev_month).find_each do |announcement|
        Rails.error.handle do
          announcement.mark_published!
        end
      end

      Event.includes(:config).where(config: { generate_monthly_announcement: true }).find_each do |event|
        Announcement::Templates::Monthly.new(event:, author: User.system_user).create
      end
    end

  end

end
