# frozen_string_literal: true

class Announcement
  class MonthlyWarningJob < ApplicationJob
    queue_as :low

    def perform
      Announcement.monthly_for(Date.today).where.not(aasm_state: :published).find_each do |announcement|
        AnnouncementMailer.with(announcement:).monthly_warning.deliver_now
      end
    end

  end

end
