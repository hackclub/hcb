# frozen_string_literal: true

class CardLockingMailer < ApplicationMailer
  def cards_locked(user:)
    @user = user
    set_transaction_data
    mail to: @user.email, subject: "[Urgent] Your HCB cards have been locked until you upload your receipts"
  end

  def warning(user:)
    @user = user
    set_transaction_data
    mail to: @user.email, subject: "[Urgent] Your HCB cards will be locked soon"
  end

  private

  def set_transaction_data
    @hcb_codes = @user.card_locking_violations
    @hcb_codes_approaching = @user.transactions_missing_receipt(from: 72.hours.ago)
    @show_org = @user.events.size > 1
  end

end
