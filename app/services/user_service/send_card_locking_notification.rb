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
      send_violation_digest = violation_digest_due?(now:)

      return unless send_warning || send_violation_digest

      CardLockingMailer.warning(user: @user).deliver_later

      return unless sms_eligible?

      TwilioMessageService::Send.new(@user, sms_message(now:)).run!
    end

    private

    def warning_due?(now:)
      warning_written = false

      User::CARD_LOCKING_WARNING_THRESHOLDS.each do |threshold|
        @user.card_locking_receipts_reaching_warning_threshold(threshold:, now:).each do |hcb_code|
          cache_written = Rails.cache.write("card_locking_warning:#{@user.id}:#{hcb_code.id}:#{threshold.to_i}", true, expires_in: 30.days, unless_exist: true)
          warning_written = true if cache_written
        end
      end

      warning_written
    end

    def violation_digest_due?(now:)
      return false unless @user.has_missing_receipt_violations?(now:)

      Rails.cache.write("card_locking_violation_digest:#{@user.id}", true, expires_in: 25.hours, unless_exist: true)
    end

    def sms_eligible?
      @user.phone_number.present? && @user.phone_number_verified?
    end

    def sms_message(now:)
      deadline_status = if @user.has_missing_receipt_violations?(now:)
                          "that are past"
                        else
                          "approaching"
                        end

      "You have receipts #{deadline_status} HCB's 72-hour upload deadline. Please upload them ASAP to reduce the risk of your cards being locked. Manage receipts at #{inbox_url}."
    end

    def inbox_url
      Rails.application.routes.url_helpers.my_inbox_url
    end

  end
end
