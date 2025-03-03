# frozen_string_literal: true

class OrganizerPosition
  class ContractsMailer < ApplicationMailer
    def notify
      @contract = params[:contract]

      mail to: @contract.organizer_position_invite.user.email_address_with_name, subject: "You've been invited to sign a contract for #{@contract.organizer_position_invite.event.name} on HCB 📝"
    end

    def notify_cosigner
      @contract = params[:contract]

      mail to: @contract.cosigner_email, subject: "You've been invited to sign a contract for #{@contract.organizer_position_invite.event.name} on HCB 📝"
    end


  end

end
