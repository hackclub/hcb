# frozen_string_literal: true

module UserService
  class SendCardLockingNotification
    def initialize(user:)
      @user = user
    end

    def run
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)

      count = @user.transactions_missing_receipt(since: Receipt::CARD_LOCKING_START_DATE).count

      if count.in?([5, 7, 9])
        CardLockingMailer.warning(email: @user.email, missing_receipts: count).deliver_later

        if @user.phone_number.present? && @user.phone_number_verified?
          message = "You now have #{count} transactions missing receipts. If you have ten or more missing receipts, your cards will be locked. You can manage your receipts at #{Rails.application.routes.url_helpers.my_inbox_url}."

          TwilioMessageService::Send.new(@user, message).run!
        end

      end
    end

  end
end
