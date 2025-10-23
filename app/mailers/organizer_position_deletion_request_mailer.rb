# frozen_string_literal: true

class OrganizerPositionDeletionRequestMailer < ApplicationMailer
  def notify_operations
    @opdr = params[:opdr]
    mail subject: "[OPDR] #{@opdr.event.name} / #{@opdr.organizer_position.user.name}", to: Credentials.fetch(:SLACK_NOTIFICATIONS_EMAIL)
  end

end
