# frozen_string_literal: true

class ContractMailer < ApplicationMailer
  before_action { @contract = params[:contract] }

  def human_follow_up
    @party = @contract.party(:hcb)
    return if @party.nil?

    mail to: @party.email, subject: @contract.human_follow_up_email_subject
  end

end
