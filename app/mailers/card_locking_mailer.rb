# frozen_string_literal: true

class CardLockingMailer < ApplicationMailer
  def cards_locked(missing_receipts:, email:)
    @missing_receipts = missing_receipts
    @email = email

    mail to: @email, subject: "[Urgent] Your HCB cards have been locked until you upload your receipts"
  end

  def warning(missing_receipts:, email:)
    @missing_receipts = missing_receipts
    @email = email

    mail to: @email, subject: "[Urgent] Your HCB cards will be locked soon"
  end

end
