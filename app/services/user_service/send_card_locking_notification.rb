# frozen_string_literal: true

module UserService
  class SendCardLockingNotification
    def initialize(user:)
      @user = user
    end

    def run
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)

      current_count = @user.transactions_missing_receipt(from: Receipt::CARD_LOCKING_START_DATE, to: 24.hours.ago).count
      future_count = @user.transactions_missing_receipt(from: Receipt::CARD_LOCKING_START_DATE).count

      if current_count.in?([5, 7, 9])
        CardLockingMailer.warning(user: @user).deliver_later

        if @user.phone_number.present? && @user.phone_number_verified?
          message = "You now have #{current_count} transactions missing receipts from more than a day ago. If you have ten or more missing receipts, your cards will be locked. You can manage your receipts at #{Rails.application.routes.url_helpers.my_inbox_url}."

          TwilioMessageService::Send.new(@user, message).run!
        end

      elsif future_count >= 10
        if @user.phone_number.present? && @user.phone_number_verified?
          message = "You have ten or more transactions missing receipts. In the next twenty-four hours, your cards will be locked unless receipts are uploaded for these transactions. You can manage your receipts at #{Rails.application.routes.url_helpers.my_inbox_url}."

          TwilioMessageService::Send.new(@user, message).run!
        end
      end
    end

  end
end
