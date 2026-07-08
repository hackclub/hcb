# frozen_string_literal: true

class MarkExistingPhoneNumbersVerified < ActiveRecord::Migration[8.0]
  def up
    # Mark all existing users with a phone number as verified.
    User.unscoped.where.not(phone_number: [nil, ""]).in_batches do |batch|
      batch.update_all(phone_number_verified: true)
    end
  end

  def down
    # No-op: verification status is not reverted.
  end
end
