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
        Rails.error.report(
          StandardError.new("card_locking_dry_run_would_lock"),
          context: { user_id: @user.id }, handled: true, severity: :info
        )
        should_lock = false
      end

      # Race-safe: only writes when the value actually changes, and cannot clobber
      # a concurrent unlock (the WHERE pins the expected prior value).
      changed = User.where(id: @user.id, cards_locked: !should_lock).update_all(cards_locked: should_lock)
      return if changed.zero?

      @user.reload
      should_lock ? notify_locked(now:) : notify_unlocked
    end

    private

    def notify_locked(now:)
      CardLockingMailer.cards_locked(user: @user).deliver_later
      send_sms(locked_message(now:))
    end

    def notify_unlocked
      CardLockingMailer.cards_unlocked(user: @user).deliver_later
      send_sms("Your HCB cards work again. Keep uploading receipts within 7 days of the charge. Manage them at #{inbox_url}.")
    end

    def locked_message(now:)
      count = @user.card_locking_overdue_charges(now:).count("hcb_codes.id")
      noun = "receipt".pluralize(count)
      verb = count == 1 ? "is" : "are"
      "Your HCB cards are locked because #{count} #{noun} #{verb} overdue. Upload to unlock in seconds at #{inbox_url}."
    end

    def send_sms(body)
      CardLocking::SendSmsJob.perform_later(user_id: @user.id, body:)
    end

    def inbox_url
      Rails.application.routes.url_helpers.my_inbox_url
    end

  end
end
