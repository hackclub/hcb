# frozen_string_literal: true

module UserService
  # Sends a once-a-day "you have receipts to upload" pile warning. No per-charge
  # countdown; names a count, never a deadline. Deduped per cardholder per day.
  class SendCardLockingNotification
    def initialize(user:)
      @user = user
    end

    def run
      return unless @user.present?
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)

      # This is a PRE-lock nudge only. Once cards are locked, the cards_locked
      # email/SMS plus the persistent banner/inbox already cover it; sending
      # this too would nag a locked user with copy about keeping cards active.
      return if @user.cards_locked?

      count = @user.card_locking_outstanding_count
      return if count.zero?

      key = "card_locking_digest:#{@user.id}"
      return unless Rails.cache.write(key, true, expires_in: 25.hours, unless_exist: true)

      deliver(count:, key:)
    end

    private

    # Keys are claimed before enqueue; release on failure so a transient error
    # does not mute the notification for the cache TTL.
    def deliver(count:, key:)
      CardLockingMailer.warning(user: @user).deliver_later
    rescue
      Rails.cache.delete(key)
      raise
    else
      CardLocking::SendSmsJob.perform_later(user_id: @user.id, body: sms_message(count))
    end

    def sms_message(count)
      noun = "receipt".pluralize(count)
      "You have #{count} #{noun} to upload. Cards that fall behind get locked. Upload them at #{inbox_url}."
    end

    # Delegates to the shared CardLocking.inbox_url helper. Falls back to the
    # route helper directly if that module method has not landed yet.
    def inbox_url
      return CardLocking.inbox_url if CardLocking.respond_to?(:inbox_url)

      Rails.application.routes.url_helpers.my_inbox_url
    end

  end
end
