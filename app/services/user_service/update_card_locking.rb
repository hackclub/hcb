# frozen_string_literal: true

module UserService
  class UpdateCardLocking
    def initialize(user:)
      @user = user
    end

    def run
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)

      violations = @user.card_locking_violations
      violation_count = violations.count

      cards_should_lock = violation_count > 0

      if cards_should_lock && !@user.cards_locked?
        CardLockingMailer.cards_locked(user: @user).deliver_later

        message = "Urgent: Your HCB cards have been locked because you have #{violation_count} #{"receipt".pluralize(violation_count)} overdue past the 72-hour deadline. Upload your receipts at #{Rails.application.routes.url_helpers.my_inbox_url}."

        TwilioMessageService::Send.new(@user, message).run!
      end

      @user.update!(cards_locked: cards_should_lock)
    end

  end
end
