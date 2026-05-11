# frozen_string_literal: true

module UserService
  class UpdateCardLocking
    def initialize(user:, unlock_only: false)
      @user = user
      @unlock_only = unlock_only
    end

    def run
      return unless @user.present?
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)

      now = Time.current
      cards_should_lock = if @unlock_only
                            @user.cards_locked? && @user.has_missing_receipt_violations?(now:)
                          else
                            @user.cards_should_lock?(now:)
                          end

      return if cards_should_lock == @user.cards_locked?

      @user.update!(cards_locked: cards_should_lock)

      if cards_should_lock
        CardLockingMailer.cards_locked(user: @user).deliver_later
        send_sms(locked_message(now:))
      else
        CardLockingMailer.cards_unlocked(user: @user).deliver_later
        send_sms("Your HCB cards have been unlocked. Please keep uploading every receipt within 72 hours of the charge settling. Manage receipts at #{Rails.application.routes.url_helpers.my_inbox_url}.")
      end
    end

    private

    def locked_message(now:)
      count = @user.card_locking_missing_receipt_violations_count(now:)
      receipt_text = "settled charge".pluralize(count)
      "Urgent: Your HCB cards have been locked because #{count} #{receipt_text} #{count == 1 ? 'is' : 'are'} still missing receipts more than 72 hours later. Upload your receipts at #{Rails.application.routes.url_helpers.my_inbox_url}."
    end

    def send_sms(message)
      return unless @user.phone_number.present? && @user.phone_number_verified?

      TwilioMessageService::Send.new(@user, message).run!
    end

  end
end
