# frozen_string_literal: true

module UserService
  class SendCardLockingNotification
    def initialize(user:)
      @user = user
    end

    def run
      return unless @user.present?
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)

      now = Time.current
      # Telling someone a receipt is approaching the deadline is noise once their
      # cards are locked. The digest covers them instead.
      claimed_keys = (@user.cards_locked? ? [] : claim_warning_keys(now:)) + claim_digest_key(now:)
      return if claimed_keys.empty?

      deliver(now:, claimed_keys:)
    end

    private

    # One key per receipt per threshold, so a receipt triggers at most one warning
    # each time it crosses a threshold.
    def claim_warning_keys(now:)
      User::CARD_LOCKING_WARNING_THRESHOLDS.flat_map do |threshold|
        @user.card_locking_receipts_reaching_warning_threshold(threshold:, now:).filter_map do |hcb_code|
          claim("card_locking_warning:#{@user.id}:#{hcb_code.id}:#{threshold.to_i}", ttl: 30.days)
        end
      end
    end

    # Locked users get a daily digest of everything still outstanding. Unlocked
    # users only get one once a receipt is past the deadline.
    def claim_digest_key(now:)
      outstanding = if @user.cards_locked?
                      @user.card_locking_missing_receipts.any?
                    else
                      @user.has_missing_receipt_violations?(now:)
                    end
      return [] unless outstanding

      [claim("card_locking_digest:#{@user.id}", ttl: 25.hours)].compact
    end

    # Returns the key when this call is the one that claimed it, otherwise nil.
    def claim(key, ttl:)
      key if Rails.cache.write(key, true, expires_in: ttl, unless_exist: true)
    end

    # Keys are claimed before the mail is enqueued, so release them if the enqueue
    # fails. Otherwise a transient failure mutes this notification for as long as
    # the keys live.
    def deliver(now:, claimed_keys:)
      CardLockingMailer.warning(user: @user).deliver_later
    rescue
      claimed_keys.each { |key| Rails.cache.delete(key) }
      raise
    else
      TwilioMessageService::Send.new(@user, sms_message(now:)).run! if sms_eligible?
    end

    def sms_eligible?
      @user.phone_number.present? && @user.phone_number_verified?
    end

    def sms_message(now:)
      return "Your HCB cards are locked. Upload your missing receipts at #{inbox_url} to get them unlocked." if @user.cards_locked?

      deadline_status = @user.has_missing_receipt_violations?(now:) ? "that are past" : "approaching"

      "You have receipts #{deadline_status} HCB's 72-hour upload deadline. Please upload them ASAP to reduce the risk of your cards being locked. Manage receipts at #{inbox_url}."
    end

    def inbox_url
      Rails.application.routes.url_helpers.my_inbox_url
    end

  end
end
