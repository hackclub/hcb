# frozen_string_literal: true

class DeleteOldTemplateDraftsJob < ApplicationJob
  queue_as :low

  def perform
    old_template_drafts = Announcement.template_draft.where("created_at < ?", 1.month.ago)
    old_template_drafts.delete_all!
  end

end
