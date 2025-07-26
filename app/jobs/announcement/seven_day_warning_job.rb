# frozen_string_literal: true

class Announcement
  class SevenDayWarningJob < ApplicationJob
    queue_as :low

    def perform
      Announcement.monthly_for(Date.today).where.not(aasm_state: :published).find_each do |announcement|
        AnnouncementMailer.with(announcement:).seven_day_warning.deliver_now
      end
    end

  end

end
