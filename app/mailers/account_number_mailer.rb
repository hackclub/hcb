# frozen_string_literal: true

class AccountNumberMailer < ApplicationMailer
  before_action :set_event_memo_and_amount_cents
  default to: -> { @event.users.map(&:email_address_with_name) }

  def insufficent_balance
    mail subject: "A direct debit for #{@event.name} was reversed due to an insufficent balance"
  end

  def debits_disabled
    mail subject: "Direct debits are disabled for #{@event.name}"
  end

  def set_event_memo_and_amount_cents
    @event = params[:event]
    @memo = params[:memo]
    @amount_cents = params[:amount_cents]
  end

end
