# frozen_string_literal: true

class CardLockingMailer < ApplicationMailer
  def cards_locked(user:)
    @user = user
    @hcb_codes = user.card_locking_overdue_charges.to_a
    @count = @hcb_codes.size
    @show_org = user.events.size > 1
    mail to: user.email, subject: "[Urgent] Your HCB cards are locked until you upload your receipts"
  end

  def cards_unlocked(user:)
    @user = user
    mail to: user.email, subject: "Your HCB cards work again"
  end

  def warning(user:)
    @user = user
    @hcb_codes = user.card_locking_outstanding_charges.to_a
    @count = @hcb_codes.size
    @show_org = user.events.size > 1
    mail to: user.email, subject: "You have #{@count} receipt#{'s' unless @count == 1} to upload"
  end

end
