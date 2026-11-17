# frozen_string_literal: true

class AddSubscriptionToLedgerItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :ledger_items, :subscription, index: { algorithm: :concurrently }
  end

end
