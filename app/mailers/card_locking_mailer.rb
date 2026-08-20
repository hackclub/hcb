# frozen_string_literal: true

class CardLockingMailer < ApplicationMailer
  helper :hcb_code # for attach_receipt_url, so recipients can upload receipts without signing in

  def cards_locked(user:)
    @user = user
    @hcb_codes = user.card_locking_overdue_charges.to_a
    @count = @hcb_codes.size
    @show_org = user.events.size > 1
    mail to: user.email, subject: "[Urgent] Your HCB cards are locked until you upload your receipts"
  end

  # suppressed_until is set when the unlock came from an admin suppression rather
  # than from the cardholder clearing their receipts. Their receipts are still
  # overdue and their cards lock again when it expires, so the copy has to say so
  # and show them what to upload. Passed in rather than read off the user here,
  # because the mail is delivered later and the suppression may have been changed
  # or lifted by then; the reason for the unlock is fixed at the moment it happens.
  def cards_unlocked(user:, suppressed_until: nil)
    @user = user
    @suppressed_until = suppressed_until

    if @suppressed_until
      @hcb_codes = user.card_locking_overdue_charges.to_a
      @count = @hcb_codes.size
      @show_org = user.events.size > 1
      @timezone = user.assumed_timezone

      mail to: user.email, subject: "Your HCB cards work again until #{@suppressed_until.in_time_zone(@timezone).strftime('%b %-d')}"
    else
      mail to: user.email, subject: "Your HCB cards work again"
    end
  end

  def warning(user:)
    @user = user
    @hcb_codes = user.card_locking_outstanding_charges.to_a
    @count = @hcb_codes.size
    @show_org = user.events.size > 1
    mail to: user.email, subject: "You have #{@count} receipt#{'s' unless @count == 1} to upload"
  end

end
