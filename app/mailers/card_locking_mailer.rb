# frozen_string_literal: true

class CardLockingMailer < ApplicationMailer
  before_action :set_delivery_reason

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

  def set_delivery_reason
    @delivery_reason = "spent funds with an HCB Visa® Commercial card and are required to upload receipts for all funds spent. #{stripe_issuing_disclosure}."
  end

  def set_transaction_data
    @hcb_codes = @user.transactions_missing_receipt(from: Receipt::CARD_LOCKING_START_DATE, to: 24.hours.ago)
    @hcb_codes_upcoming = @user.transactions_missing_receipt(from: 24.hours.ago)
    @show_org = @user.events.size > 1
  end

end
