# frozen_string_literal: true

class Announcement
  class SevenDayWarningJob < ApplicationJob
    queue_as :low

    def perform
      Announcement.monthly_for(Date.today).where.not(aasm_state: :published).find_each do |announcement|
        if announcement.blocks.any?(&:empty?)
          AnnouncementMailer.with(announcement:).canceled.deliver_now
        else
          AnnouncementMailer.with(announcement:).seven_day_warning.deliver_now
        end
      end
    end

  end

end
