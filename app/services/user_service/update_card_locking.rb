# frozen_string_literal: true

module UserService
  class UpdateCardLocking
    def initialize(user:, unlock_only: false)
      @user = user
      @unlock_only = unlock_only
    end

    def run
      return unless @user.present?
      return unless Flipper.enabled?(:card_locking_2025_06_09, @user)
      return if @unlock_only && !@user.cards_locked?

      now = Time.current
      should_lock = @user.card_locking_suppressed?(now:) ? false : @user.card_locking_has_overdue_charge?(now:)

      # Uploading a receipt can only ever unlock. If a charge is still overdue,
      # leave the lock exactly as it is (do NOT unlock with work outstanding).
      return if @unlock_only && should_lock

      # Dry run: never write a lock, but always allow unlocking. Record the
      # would-be lock so we can measure the real population before enforcing.
      if should_lock && !Flipper.enabled?(:card_locking_enforcement, @user)
        report_dry_run_would_lock
        should_lock = false
      end

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

    def report_dry_run_would_lock
      # Enforcement is off, so this path runs on every cron tick. Dedup on a
      # daily-ish key so telemetry captures the would-be lock once per window
      # (per transition), not once per tick.
      key = "card_locking_dry_run:#{@user.id}"
      return unless Rails.cache.write(key, true, expires_in: 25.hours, unless_exist: true)

      Rails.error.report(
        StandardError.new("card_locking_dry_run_would_lock"),
        context: { user_id: @user.id }, handled: true, severity: :info
      )
    end

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

    def send_sms(body)
      CardLocking::SendSmsJob.perform_later(user_id: @user.id, body:)
    end

  end
end
