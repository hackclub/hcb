# frozen_string_literal: true

module Maintenance
  # One-time backfill: locking a user now freezes every active card they hold,
  # but users locked before that, or while freezing was an opt-in checkbox,
  # can still have active cards. Freezes them, matching what `User#lock!` does
  # now. Run once after deploying.
  class FreezeLockedUsersCardsTask < MaintenanceTasks::Task
    def collection
      User.where.not(locked_at: nil)
    end

    def process(user)
      # The user may have been unlocked since the collection was loaded.
      return unless user.locked?

      user.stripe_cards.active.find_each(&:freeze!)
    end

  end
end
