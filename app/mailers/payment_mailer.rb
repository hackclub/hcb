# frozen_string_literal: true

class PaymentMailer < ApplicationMailer
  before_action :set_payment

  def missing_payout_method
    @initial = params[:initial]
    mail to: @recipients, subject: params[:initial] ? initial_subject : "[Action Required] Configure a payout method for \"#{@payment.purpose}\" from #{@payment.event.name}"
  end

  def missing_tax_information
    mail to: @recipients, subject: initial_subject
  end

  def sent
    mail to: @recipients, subject: "Your payment for \"#{@payment.purpose}\" is on the way!"
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
