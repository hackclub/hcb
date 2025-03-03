# frozen_string_literal: true

class OrganizerPositionDeletionRequestMailerPreview < ActionMailer::Preview
  def notify_operations
    OrganizerPositionDeletionRequestMailer.with(opdr: OrganizerPositionDeletionRequest.last).notify_operations
  end

end
