# frozen_string_literal: true

module UserService
  class UpdateCardLocking
    def initialize(user:, unlock_only: false, notify_progress: false)
      @user = user
      @unlock_only = unlock_only
      @notify_progress = notify_progress
    end

    def run
      return unless @user.present?
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)
      return if @unlock_only && !@user.cards_locked?

      now = Time.current
      should_lock = @user.card_locking_suppressed?(now:) ? false : @user.card_locking_has_overdue_charge?(now:)

      # Uploading a receipt can only ever unlock. If a charge is still overdue,
      # leave the lock exactly as it is (do NOT unlock with work outstanding), but
      # tell a cardholder who just uploaded that it landed and more remain, so the
      # "upload to unlock" promise does not appear to have done nothing.
      if @unlock_only && should_lock
        notify_still_locked(now:) if @notify_progress && @user.cards_locked?
        return
      end

      # Enforcement is staged per cardholder by CardLocking.enforcement_start_date:
      # a charge only gets a deadline (and can be overdue here) once its cardholder
      # is in a rollout stage. So should_lock is already false for anyone not yet
      # enrolled; no separate dry-run gate is needed.

      # Row-locked compare-and-set: only writes on an actual transition, and
      # cannot clobber a concurrent unlock because cards_locked is re-read under
      # the lock. Unlike update_all, save! runs callbacks and records a
      # PaperTrail version, preserving the who/when audit trail for the lock
      # state change.
      #
      # NOTE: we cannot use `with_lock`/`lock!` here. `User#lock!` is overridden
      # to lock the *account* (sets locked_at, signs out sessions, revokes API
      # tokens), so `reload(lock: true)` takes the row lock (SELECT ... FOR
      # UPDATE) without triggering that.
      #
      # save!(validate: false) is deliberate: the lock write must not be coupled
      # to unrelated User validations (a legacy-invalid email/phone would
      # otherwise raise and leave a card stuck locked after a valid upload).
      # after_update and PaperTrail hook on save, not validation, so the audit
      # trail is still recorded.
      transitioned = false
      User.transaction do
        @user.reload(lock: true)
        unless @user.cards_locked == should_lock
          @user.cards_locked = should_lock
          @user.save!(validate: false)
          transitioned = true
        end
      end
      return unless transitioned

      # Enqueue notifications outside the row lock, gated on the transition.
      should_lock ? notify_locked(now:) : notify_unlocked
    end

    private

    def notify_locked(now:)
      CardLockingMailer.cards_locked(user: @user).deliver_later
      send_sms(locked_message(now:))
    end

    def notify_unlocked
      CardLockingMailer.cards_unlocked(user: @user).deliver_later
      send_sms("Your HCB cards work again. Keep uploading receipts within 7 days of the charge. Manage them at #{CardLocking.inbox_url}.")
    end

    def locked_message(now:)
      count = @user.card_locking_overdue_charges(now:).count("hcb_codes.id")
      noun = "receipt".pluralize(count)
      verb = count == 1 ? "is" : "are"
      "Your HCB cards are locked because #{count} #{noun} #{verb} overdue. Recurring charges will also fail until you upload. Upload to unlock in seconds at #{CardLocking.inbox_url}."
    end

    # A receipt landed for a still-locked cardholder (uploaded by them or a
    # teammate on their behalf) but overdue charges remain. Confirm the progress to
    # the cardholder so the upload does not look like it did nothing. SMS only, and
    # deduped so a burst of uploads does not spam.
    def notify_still_locked(now:)
      key = "card_locking_still_locked:#{@user.id}"
      return unless Rails.cache.write(key, true, expires_in: 10.minutes, unless_exist: true)

      count = @user.card_locking_overdue_charges(now:).count("hcb_codes.id")
      return if count.zero?

      noun = "receipt".pluralize(count)
      verb = count == 1 ? "is" : "are"
      pronoun = count == 1 ? "it" : "them"
      send_sms("Thanks, that receipt is in. #{count} #{noun} #{verb} still overdue. Upload #{pronoun} to unlock your cards at #{CardLocking.inbox_url}.")
    end

    def send_sms(body)
      User::SendSmsJob.perform_later(user_id: @user.id, body:)
    end

  end
end
