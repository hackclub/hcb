# frozen_string_literal: true

class Announcement
  class MonthlyJob < ApplicationJob
    queue_as :default

    def perform
      Announcement.approved_monthly_for(Date.today.prev_month).find_each do |announcement|
        Rails.error.handle do
          announcement.mark_published!
        end

        Announcement::Templates::Monthly.new(event: announcement.event, author: User.system_user).create
      end
    end

  end

end
