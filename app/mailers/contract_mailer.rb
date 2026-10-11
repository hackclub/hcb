# frozen_string_literal: true

class ContractMailer < ApplicationMailer
  before_action { @contract = params[:contract] }

  def human_follow_up
    @party = @contract.party(:hcb)
    return if @party.nil?

    mail to: @party.email, subject: human_follow_up_email_subject
  end

  private

  def human_follow_up_email_subject
    "[Update] #{@contract.event_name}'s #{@contract.agreement_name} still isn't signed 📝"
  end

end
