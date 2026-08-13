# frozen_string_literal: true

module UserService
  # Sends a once-a-day "you have receipts to upload" pile warning. No per-charge
  # countdown; names a count, never a deadline. Deduped per cardholder per day.
  class SendCardLockingNotification
    def initialize(user:, now: Time.current)
      @user = user
      @now = now
    end

    def run
      return unless @user.present?
      return unless CardLocking.enabled?

      # This is a PRE-lock nudge only. Once cards are locked, the cards_locked
      # email/SMS plus the persistent banner/inbox already cover it; sending
      # this too would nag a locked user with copy about keeping cards active.
      return if @user.cards_locked?

      # A cardholder under an admin exception gets a different, gentler sequence.
      # The daily digest below would tell someone who was just granted time that
      # their cards "will lock until you do", every day for up to a month.
      return run_suppressed if @user.card_locking_suppressed?(now: @now)

      # Only nudge when at least one charge is actually approaching its deadline.
      # A cardholder whose charges are all still fresh (a full week of runway)
      # should not get a daily "you have receipts to upload" email; that trains
      # them to ignore the warning that matters. The count below is still the whole
      # outstanding pile, so they can clear all of it while they are here.
      return unless @user.card_locking_has_approaching_charge?

      count = @user.card_locking_outstanding_count
      return if count.zero?

      # The recurring job runs every few minutes; this dedup key is the only thing
      # that makes the digest daily. TTL is under 24h on purpose: at 23h the send
      # time drifts a little earlier each day, guaranteeing one per calendar date.
      # A 24h+ TTL drifts later instead and can skip a date entirely.
      key = "card_locking_digest:#{@user.id}"
      return unless Rails.cache.write(key, true, expires_in: 23.hours, unless_exist: true)

      deliver(count:, key:)
    end

    private

    # The exception sequence, one message per sweep, most urgent first. The
    # reminder is only eligible while more than WARNING_LEAD_TIME remains and the
    # notices only once less does, so a short exception cannot fire a reminder and
    # an ending notice minutes apart.
    #
    # Keyed off time remaining rather than how long the exception was granted for:
    # only card_locking_suppressed_until is stored, so the window length is not
    # knowable here.
    def run_suppressed
      suppressed_until = @user.card_locking_suppressed_until
      remaining = suppressed_until - @now

      count = @user.card_locking_overdue_charges(now: @now).count("hcb_codes.id")
      return if count.zero?

      if remaining <= CardLocking::SUPPRESSION_FINAL_LEAD
        deliver_ending(suppressed_until:, stage: :final, final: true)
      elsif remaining <= CardLocking::WARNING_LEAD_TIME
        deliver_ending(suppressed_until:, stage: :ending, final: false)
      else
        deliver_reminder(suppressed_until:, count:)
      end
    end

    # Once per deadline. Keying on suppressed_until is what re-arms an extended or
    # shortened exception: a new deadline is a new key, so the cardholder is told
    # about the date that now applies.
    def deliver_ending(suppressed_until:, stage:, final:)
      key = CardLocking.suppression_notice_key(stage, @user.id, suppressed_until)
      return unless Rails.cache.write(key, true, expires_in: 30.days, unless_exist: true)

      begin
        CardLockingMailer.suppression_ending(user: @user, suppressed_until:, final:).deliver_later
      rescue
        Rails.cache.delete(key)
        raise
      end

      User::SendSmsJob.perform_later(user_id: @user.id, body: ending_sms(suppressed_until:, final:))
    end

    # Email only. SMS is the intrusive channel and this cardholder was granted
    # relief, so it is held back for the ending notices and the lock itself. The
    # unlock notice claims this key when the exception starts, so the first
    # reminder lands an interval later rather than on the next sweep.
    def deliver_reminder(suppressed_until:, count:)
      key = CardLocking.suppression_notice_key(:reminder, @user.id)
      return unless Rails.cache.write(key, true, expires_in: CardLocking::SUPPRESSION_REMINDER_INTERVAL, unless_exist: true)

      begin
        CardLockingMailer.suppression_reminder(user: @user, suppressed_until:).deliver_later
      rescue
        Rails.cache.delete(key)
        raise
      end
    end

    def ending_sms(suppressed_until:, final:)
      count = @user.card_locking_overdue_charges(now: @now).count("hcb_codes.id")
      noun = "receipt".pluralize(count)
      deadline = CardLocking.format_deadline(suppressed_until, @user.assumed_timezone)
      when_it_ends = final ? "in about an hour, at #{deadline}" : "on #{deadline}"

      "Your HCB card locking exception ends #{when_it_ends}. Upload your #{count} overdue #{noun} before then or your cards will lock. #{CardLocking.inbox_url}"
    end

    # Keys are claimed before enqueue; release on failure so a transient error
    # does not mute the notification for the cache TTL.
    def deliver(count:, key:)
      CardLockingMailer.warning(user: @user).deliver_later
    rescue
      Rails.cache.delete(key)
      raise
    else
      User::SendSmsJob.perform_later(user_id: @user.id, body: sms_message(count))
    end

    def sms_message(count)
      noun = "receipt".pluralize(count)
      "You have #{count} #{noun} to upload. Your cards will lock until you do. Upload at #{CardLocking.inbox_url}."
    end

  end
end
