# frozen_string_literal: true

class Contract
  class PartyMailer < ApplicationMailer
    def notify
      @party = params[:party]
      @contract = @party.contract

      mail to: @party.email,
           subject: @party.notify_email_subject,
           template_name: "notify_#{@party.role}"
    end

  end

end
