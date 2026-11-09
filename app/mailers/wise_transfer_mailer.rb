# frozen_string_literal: true

class WiseTransferMailer < ApplicationMailer
  def notify_failed
    @wise_transfer = params[:wise_transfer]
    @reason = params[:reason]
    @returned = params[:returned]

    mail subject: "[HCB] Wise transfer to #{@wise_transfer.recipient_name} failed to send", to: @wise_transfer.user.email
  end

end
