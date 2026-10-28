# frozen_string_literal: true

class AccountNumberMailer < ApplicationMailer
  include IndividualDelivery

  before_action :set_event_memo_and_amount_cents

  def insufficient_balance
    mail_individually @event.organizer_contact_emails, subject: "A direct debit for #{@event.name} was reversed due to an insufficient balance"
  end

  def debits_disabled
    mail_individually @event.organizer_contact_emails, subject: "Direct debits are disabled for #{@event.name}"
  end

  def set_event_memo_and_amount_cents
    @event = params[:event]
    @memo = params[:memo]
    @amount_cents = params[:amount_cents]
  end

end
