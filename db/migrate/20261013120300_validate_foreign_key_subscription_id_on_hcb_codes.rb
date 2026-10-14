# frozen_string_literal: true

class ValidateForeignKeySubscriptionIdOnHcbCodes < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :hcb_codes, :subscriptions
  end

end
