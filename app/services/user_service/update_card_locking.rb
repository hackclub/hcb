# frozen_string_literal: true

module UserService
  class UpdateCardLocking
    def initialize(user:)
      @user = user
    end

    def run
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)

      count = @user.transactions_missing_receipt(from: Receipt::CARD_LOCKING_START_DATE, to: 24.hours.ago).count

      cards_should_lock = count >= 10
      if cards_should_lock && !@user.cards_locked?
        CardLockingMailer.cards_locked(user: @user).deliver_later

        message = "Urgent: Your HCB cards have been locked because you have #{count} transactions missing receipts. To unlock your cards, upload your receipts at #{Rails.application.routes.url_helpers.my_inbox_url}."

        TwilioMessageService::Send.new(@user, message).run!
      end

      @user.update!(cards_locked: cards_should_lock)
    end

  end
end
