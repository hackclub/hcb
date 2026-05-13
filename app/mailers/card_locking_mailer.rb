# frozen_string_literal: true

class CardLockingMailer < ApplicationMailer
  def cards_locked(user:)
    @user = user
    set_transaction_data
    mail to: @user.email, subject: "[Urgent] Your HCB cards have been locked until you upload your receipts"
  end

  def cards_unlocked(user:)
    @user = user
    mail to: @user.email, subject: "Your HCB cards have been unlocked"
  end

  def warning(user:)
    @user = user
    set_transaction_data
    mail to: @user.email, subject: "[Urgent] Your HCB cards will be locked soon"
  end

  private

  def set_transaction_data
    @hcb_codes, @hcb_codes_upcoming = @user.card_locking_missing_receipts_partitioned
    @show_org = @user.events.size > 1
  end

end
