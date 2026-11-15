# frozen_string_literal: true

class ValidateForeignKeySubscriptionIdOnLedgerItems < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :ledger_items, :subscriptions
  end

end
