# frozen_string_literal: true

class OrganizerPositionDeletionRequestMailer < ApplicationMailer
  def notify_operations
    @opdr = params[:opdr]
    mail subject: "[OPDR] #{@opdr.event.name} / #{@opdr.organizer_position.user.name}", to: Rails.application.credentials.admin_email[:slack]
  end

end
