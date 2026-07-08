# frozen_string_literal: true

class DisableExistingNotificationSettings < ActiveRecord::Migration[8.0]
  def up
    # Transaction comment notifications and card charge notifications are
    # permanently disabled. Turn them off for all existing users.
    # comment_notifications: no_threads = 2, charge_notifications: nothing = 3
    User.unscoped.in_batches do |batch|
      batch.update_all(comment_notifications: 2, charge_notifications: 3)
    end
  end

  def down
    # No-op: these settings are intentionally disabled and cannot be re-enabled.
  end
end
