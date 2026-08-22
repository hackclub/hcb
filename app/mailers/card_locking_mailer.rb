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

  # suppressed_until means an admin granted the unlock rather than the cardholder
  # clearing receipts: the receipts are still overdue and the cards lock again
  # when it expires, so the copy has to say so. Passed in rather than read off the
  # user, because delivery is deferred and the suppression may change by then.
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

  # A courtesy nudge partway through an exception. Names the deadline the
  # cardholder already has rather than threatening a lock, as the ordinary
  # pre-lock digest would.
  def suppression_reminder(user:, suppressed_until:)
    assign_suppression(user:, suppressed_until:)

    mail to: user.email, subject: "You have #{@count} #{'receipt'.pluralize(@count)} to upload before #{@suppressed_until.in_time_zone(@timezone).strftime('%b %-d')}"
  end

  # `final` is the last call, roughly an hour out. Deliberately vague about how
  # long: the sweep runs every few minutes, so a countdown would be wrong.
  def suppression_ending(user:, suppressed_until:, final: false)
    assign_suppression(user:, suppressed_until:)
    @final = final

    subject = if final
                "Your card locking exception ends in about an hour"
              else
                "Your card locking exception ends #{@suppressed_until.in_time_zone(@timezone).strftime('%b %-d')}"
              end

    mail to: user.email, subject:
  end

  def warning(user:)
    @user = user
    @hcb_codes = user.card_locking_outstanding_charges.to_a
    @count = @hcb_codes.size
    # Same countdown the warning SMS carries, off the same pile. Taken from the
    # loaded rows rather than a second query, so mail and text agree exactly.
    @due_in = CardLocking.time_remaining_in_words(@user.card_locking_next_due_at)
    @show_org = user.events.size > 1
    mail to: user.email, subject: "You have #{@count} receipt#{'s' unless @count == 1} to upload"
  end

  private

  # Overdue charges rather than the whole outstanding pile, because overdue is
  # what locks the cards when the exception ends.
  def assign_suppression(user:, suppressed_until:)
    @user = user
    @suppressed_until = suppressed_until
    @hcb_codes = user.card_locking_overdue_charges.to_a
    @count = @hcb_codes.size
    @show_org = user.events.size > 1
    @timezone = user.assumed_timezone
  end

end
