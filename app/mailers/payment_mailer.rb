# frozen_string_literal: true

class PaymentMailer < ApplicationRecord
  before_action :set_payment

  def missing_payment_method
    mail to: @recipients, subject: params[:initial] ? initial_subject : "[Action Required] Configure a payout method for \"#{@payment.purpose}\" from #{@payment.event.name}"
  end

  def missing_information
    mail to: @recipients, subject: initial_subject
  end

  def sent
    mail to: @recipients, subject: "Your payment for \"#{@payment.purpose}\" is on the way!"
  end

  def rejected
    mail to: @creator, subject: "Your payment to #{@payment.payee.preferred_name} was rejected"
  end

  def failed_creator
    mail to: @creator, subject: "[Action Required] Your payment to #{@payment.payee.preferred_name} failed to send"
  end

  def failed_payee
    @reason = params[:reason]
    mail to: @recipients, subject: "We couldn't send you your payment for #{@payment.purpose} from #{@payment.event.name}"
  end

  private

  def initial_subject
    "[Action Required] You're being paid #{ApplicationController.helpers.render_money(@payment.amount_cents)} for \"#{@payment.purpose}\" from #{@payment.event.name}"
  end

  def set_payment
    @payment = params[:payment]
    @recipients = @payment.payee.legal_entity.users.map(&:email_address_with_name)
    @creator = @payment.creator.email_address_with_name
  end

end
