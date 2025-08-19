# frozen_string_literal: true

class Announcement
  class TwoDayWarningJob < ApplicationJob
    queue_as :low

    def perform
      Announcement.monthly_for(Date.today).where(aasm_state: :template_draft).find_each do |announcement|
        AnnouncementMailer.with(announcement:).two_day_warning.deliver_now
      end
    end

  end

end
