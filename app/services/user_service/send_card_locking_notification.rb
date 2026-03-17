# frozen_string_literal: true

module UserService
  class SendCardLockingNotification
    def initialize(user:)
      @user = user
    end

    def run
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)
      return if @user.cards_locked?

      # Transactions approaching the 72-hour deadline (between 47-49h old)
      approaching_deadline = @user.transactions_missing_receipt(from: Receipt::CARD_LOCKING_START_DATE, to: 47.hours.ago)
                                  .where("created_at >= ?", 49.hours.ago)

      # Transactions urgently near deadline (between 71-73h old)
      urgent_deadline = @user.transactions_missing_receipt(from: Receipt::CARD_LOCKING_START_DATE, to: 71.hours.ago)
                             .where("created_at >= ?", 73.hours.ago)

      if urgent_deadline.any?
        CardLockingMailer.warning(user: @user).deliver_later

        if @user.phone_number.present? && @user.phone_number_verified?
          message = "Urgent: You have #{urgent_deadline.count} #{"receipt".pluralize(urgent_deadline.count)} due within the next hour. Your cards will be locked if receipts are not uploaded within the 72-hour deadline. Upload at #{Rails.application.routes.url_helpers.my_inbox_url}."

          TwilioMessageService::Send.new(@user, message).run!
        end
      elsif approaching_deadline.any?
        CardLockingMailer.warning(user: @user).deliver_later

        if @user.phone_number.present? && @user.phone_number_verified?
          message = "Reminder: You have #{approaching_deadline.count} #{"transaction".pluralize(approaching_deadline.count)} with receipts due in the next 24 hours. Upload your receipts at #{Rails.application.routes.url_helpers.my_inbox_url} to avoid having your cards locked."

          TwilioMessageService::Send.new(@user, message).run!
        end
      end
    end

  end
end
