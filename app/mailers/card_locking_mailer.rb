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

  # Doubles as the recurring digest for users whose cards are already locked, so
  # they keep seeing what they need to upload to get unlocked.
  def warning(user:)
    @user = user
    set_transaction_data
    subject = if @cards_locked
                "[Urgent] Your HCB cards are locked until you upload your receipts"
              else
                "[Urgent] Your HCB cards will be locked soon"
              end

    mail to: @user.email, subject:
  end

  private

  def set_transaction_data
    @hcb_codes, @hcb_codes_upcoming = @user.card_locking_missing_receipts_partitioned
    @total_missing_count = @hcb_codes.count + @hcb_codes_upcoming.count
    @show_org = @user.events.size > 1
    @cards_locked = @user.cards_locked?
  end

end
