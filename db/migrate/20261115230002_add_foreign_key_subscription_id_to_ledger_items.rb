# frozen_string_literal: true

class AddForeignKeySubscriptionIdToLedgerItems < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :ledger_items, :ledger_subscriptions, column: :subscription_id, on_delete: :nullify, validate: false
  end

end
