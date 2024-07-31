# frozen_string_literal: true

class GrantMailer < ApplicationMailer
  def invitation
    @grant = params[:grant]

    mail to: @grant.recipient.email_address_with_name, subject: "Grant invitation from #{@grant.event.name}", from: email_address_with_name("hcb@hackclub.com", "#{@grant.event.name} via HCB")
  end

  def approved
    @grant = params[:grant]

    mail to: @grant.submitted_by.email_address_with_name, subject: "Grant to #{@grant.recipient_name} approved and sent"
  end

end
