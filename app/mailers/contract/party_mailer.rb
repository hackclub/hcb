# frozen_string_literal: true

class Contract
  class PartyMailer < ApplicationMailer
    before_action :set_party

    def notify
      mail to: @party.email,
           subject: @party.notify_email_subject,
           template_name: "notify_#{@party.role}"
    end

    def reissued
      @message = params[:message]

      mail to: @party.email,
           subject: @party.reissue_email_subject,
           template_name: "reissue_#{@party.role}"
    end

    private

    def set_party
      @party = params[:party]
      @contract = @party.contract
    end

  end

end
