# frozen_string_literal: true

module UserService
  class UpdateCardLocking
    def initialize(user:)
      @user = user
    end

    def run
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)

      count = @user.transactions_missing_receipt(since: Receipt::CARD_LOCKING_START_DATE).count

      cards_should_lock = count >= 10
      if cards_should_lock && !@user.cards_locked?
        CardLockingMailer.cards_locked(email: @user.email, missing_receipts: count).deliver_later
      end

      @user.update!(cards_locked: cards_should_lock)
    end

  end
end
