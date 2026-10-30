# frozen_string_literal: true

class PaymentRecipientsController < ApplicationController
  def destroy
    payment_recipient = authorize PaymentRecipient.find(params[:id])

    payment_recipient.destroy!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove_all("[data-payment-recipient='#{payment_recipient.hashid}']") }
      format.any { redirect_back fallback_location: new_event_ach_transfer_path(payment_recipient.event) }
    end
  end

end
