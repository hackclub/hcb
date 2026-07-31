# frozen_string_literal: true

class CardLockingMailer < ApplicationMailer
  before_action :set_delivery_reason

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

  private

  def set_delivery_reason
    @delivery_reason = "you spent funds with an HCB Visa® Commercial card and are required to upload receipts for all funds spent. #{stripe_issuing_disclosure}"
  end

  def set_transaction_data
    @hcb_codes = @user.transactions_missing_receipt(from: Receipt::CARD_LOCKING_START_DATE, to: 24.hours.ago)
    @hcb_codes_upcoming = @user.transactions_missing_receipt(from: 24.hours.ago)
    @show_org = @user.events.size > 1
  end

end
