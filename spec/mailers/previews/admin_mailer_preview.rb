# frozen_string_literal: true

class AdminMailerPreview < ActionMailer::Preview
  def opdr_notification
    AdminMailer.with(opdr: OrganizerPositionDeletionRequest.last).opdr_notification
  end

  def reminders
    AdminMailer.reminders
  end

end
