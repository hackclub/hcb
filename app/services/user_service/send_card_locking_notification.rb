# frozen_string_literal: true

module UserService
  class SendCardLockingNotification
    def initialize(user:)
      @user = user
    end

    def run
      return unless @user.present?
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)
      return if @user.cards_locked?

      now = Time.current
      send_warning = warning_due?(now:)
      send_digest = violation_digest_due?(now:)

      return unless send_warning || send_digest

      CardLockingMailer.warning(user: @user).deliver_later

      return unless @user.phone_number.present? && @user.phone_number_verified?

      TwilioMessageService::Send.new(@user, sms_message(now:)).run!
    end

    private

    def warning_due?(now:)
      User::CARD_LOCKING_WARNING_THRESHOLDS.any? do |threshold|
        @user.card_locking_receipts_reaching_warning_threshold(threshold:, now:).any? do |hcb_code|
          Rails.cache.write("card_locking_warning:#{@user.id}:#{hcb_code.id}:#{threshold.to_i}", true, expires_in: 30.days, unless_exist: true)
        end
      end
    end

    def violation_digest_due?(now:)
      return false unless @user.has_missing_receipt_violations?(now:)

      Rails.cache.write("card_locking_violation_digest:#{@user.id}", true, expires_in: 25.hours, unless_exist: true)
    end

    def sms_message(now:)
      base_url = Rails.application.routes.url_helpers.my_inbox_url

      if @user.has_missing_receipt_violations?(now:)
        "You have receipts that are past HCB's 72-hour upload deadline. Please upload them ASAP to reduce the risk of your cards being locked. Manage receipts at #{base_url}."
      else
        "You have receipts approaching HCB's 72-hour upload deadline. Please upload them ASAP to reduce the risk of your cards being locked. Manage receipts at #{base_url}."
      end
    end
  end
end
