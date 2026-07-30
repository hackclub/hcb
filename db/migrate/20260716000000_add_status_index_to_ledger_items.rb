# frozen_string_literal: true

class AddStatusIndexToLedgerItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :ledger_items, :status, algorithm: :concurrently
  end
end
