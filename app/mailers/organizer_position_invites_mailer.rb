# frozen_string_literal: true

class OrganizerPositionInvitesMailer < ApplicationMailer
  def notify
    @invite = params[:invite]

    mail to: @invite.user.email_address_with_name, subject: "You've been invited to join #{@invite.event.name} on HCB 🚀"
  end

end
