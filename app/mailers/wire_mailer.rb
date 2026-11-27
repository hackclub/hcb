# frozen_string_literal: true

class WireMailer < ApplicationMailer
  def notify_recipient
    @wire = params[:wire]

    mail to: @wire.recipient_email,
         subject: "Your wire transfer from #{@wire.event.name} has been sent",
         from: hcb_email_with_name_of(@wire.event)
  end

  def notify_failed
    @wire = params[:wire]
    @reason = params[:reason]

    mail subject: "[HCB] Wire to #{@wire.recipient_name} failed to send", to: @wire.user.email
  end

end
