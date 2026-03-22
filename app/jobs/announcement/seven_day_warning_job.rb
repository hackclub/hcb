# frozen_string_literal: true

class Announcement
  class SevenDayWarningJob < ApplicationJob
    queue_as :low

    def perform
      Announcement.monthly_for(Date.today).where.not(aasm_state: :published).find_each do |announcement|
        # If a monthly announcement is still a template draft, then that means it has not been edited.
        # So, if it has not been edited and has empty blocks (no data), the managers will be notified
        # that the announcement will be skipped. At the beginning of the month, these announcements will
        # not be published unless edited since template drafts cannot transition to published, and monthly
        # announcements that have block with data will be promoted to drafts in this job.

        if announcement.template_draft? && announcement.blocks.any?(&:empty?)
          AnnouncementMailer.with(announcement:).skipped.deliver_now
        else
          if announcement.template_draft?
            announcement.mark_draft!
          end

          AnnouncementMailer.with(announcement:).seven_day_warning.deliver_later
        end
      end
    end

  end

end
