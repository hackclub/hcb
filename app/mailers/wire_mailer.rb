# frozen_string_literal: true

class WireMailer < ApplicationMailer
  def notify_failed
    @wire = params[:wire]
    @reason = params[:reason]

    mail subject: "[HCB] Wire to #{@wire.recipient_name} failed to send", to: @wire.user.email
  end

end
