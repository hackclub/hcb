# frozen_string_literal: true

class AddUniqueIndexToLedgerItemPinsOnLedgerItemId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :ledger_item_pins, :ledger_item_id, algorithm: :concurrently

    add_index :ledger_item_pins, :ledger_item_id, unique: true, algorithm: :concurrently
  end

end
