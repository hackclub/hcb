# frozen_string_literal: true

class Contract
  class PartyMailer < ApplicationMailer
    def notify
      @party = params[:party]
      @contract = @party.contract

      mail to: @party.email,
           subject: "You've been invited to sign a contract for #{@contract.event.name} on HCB 📝",
           template_path: "contract/party_mailer/notify_#{@party.role}"
    end

  end

end
