# frozen_string_literal: true

module UserService
  # Sends a once-a-day "you have receipts to upload" pile warning: the size of the
  # outstanding pile plus a countdown to the soonest deadline in it. Deduped per
  # cardholder per day.
  class SendCardLockingNotification
    def initialize(user:)
      @user = user
    end

    def run
      return unless @user.present?
      return unless CardLocking.enabled?

      # This is a PRE-lock nudge only. Once cards are locked, the cards_locked
      # email/SMS plus the persistent banner/inbox already cover it; sending
      # this too would nag a locked user with copy about keeping cards active.
      return if @user.cards_locked?

      # Only nudge when at least one charge is actually approaching its deadline.
      # A cardholder whose charges are all still fresh (a full week of runway)
      # should not get a daily "you have receipts to upload" email; that trains
      # them to ignore the warning that matters. The count below is still the whole
      # outstanding pile, so they can clear all of it while they are here.
      return unless @user.card_locking_has_approaching_charge?

      count = @user.card_locking_outstanding_count
      return if count.zero?

      due_at = @user.card_locking_next_due_at

      # The recurring job runs every few minutes; this dedup key is the only thing
      # that makes the digest daily. TTL is under 24h on purpose: at 23h the send
      # time drifts a little earlier each day, guaranteeing one per calendar date.
      # A 24h+ TTL drifts later instead and can skip a date entirely.
      key = "card_locking_digest:#{@user.id}"
      return unless Rails.cache.write(key, true, expires_in: 23.hours, unless_exist: true)

      deliver(count:, due_at:, key:)
    end

    private

    # Keys are claimed before enqueue; release on failure so a transient error
    # does not mute the notification for the cache TTL.
    def deliver(count:, due_at:, key:)
      CardLockingMailer.warning(user: @user).deliver_later
    rescue
      Rails.cache.delete(key)
      raise
    else
      User::SendSmsJob.perform_later(user_id: @user.id, body: sms_message(count, due_at))
    end

    # Cards are NOT locked here (see the guard above), so the copy has to be a
    # countdown, not a status: name the pile, then the soonest deadline in it.
    # A bare count plus "your cards will lock" reads as if they already have.
    #
    # The deadline can be missing (a suppressed cardholder, or one whose pile is
    # all pre-enforcement) or already past (the enforcement job has not caught up
    # yet); neither can carry a countdown, so those fall back to the rule itself.
    def sms_message(count, due_at)
      noun = "receipt".pluralize(count)
      remaining = CardLocking.time_remaining_in_words(due_at)

      deadline =
        if remaining.nil?
          # We think this isn't possible??? maybe 🤷‍♂️
          "Your cards lock once a receipt goes past its deadline."
        elsif count == 1
          "It's due in #{remaining}. Miss it and your cards lock."
        else
          "Your next receipt is due in #{remaining}. Miss it and your cards lock."
        end

      "You have #{count} #{noun} to upload. #{deadline} Upload at #{CardLocking.inbox_url}."
    end

  end
end
