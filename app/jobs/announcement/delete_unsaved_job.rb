# frozen_string_literal: true

class Announcement
  class DeleteUnsavedJob < ApplicationJob
    queue_as :low

    def perform
      unsaved_announcements = Announcement.saved.invert_where.where("created_at < ?", 2.months.ago)
      unsaved_announcements.destroy_all
    end

  end

end

DeleteOldTemplateDraftsJob = Announcement::DeleteUnsavedJob
