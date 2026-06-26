# frozen_string_literal: true

class Payment
  class AttemptMailer < ApplicationMailer
    before_action :set_attempt

    def failed_creator
      mail to: @creator, subject: "[Action Required] Your payment to #{@payment.payee.preferred_name} failed to send"
    end

    def failed_payee
      @reason = params[:reason]
      mail to: @recipients, subject: "We couldn't send your payment for #{@payment.purpose} from #{@payment.event.name}"
    end

    private

    def set_attempt
      @attempt = params[:attempt]
      @payment = @attempt.payment
      @recipients = @payment.legal_entity.users.map(&:email_address_with_name)
      @creator = @payment.creator.email_address_with_name
    end

  end

end
